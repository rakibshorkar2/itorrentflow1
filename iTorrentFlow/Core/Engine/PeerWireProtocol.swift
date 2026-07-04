import Foundation
import Network

// MARK: - Peer Wire Protocol
/// Implements the BitTorrent peer wire protocol (BEP 3)
public actor PeerConnection {
    public let host: String
    public let port: UInt16
    public let infoHash: Data
    public let localPeerID: Data

    private var connection: NWConnection?
    private var handshakeDone = false
    private var bitfield: [Bool] = []
    private var amChoked = true
    private var amInterested = false
    private var peerChoked = true
    private var peerInterested = false

    // MARK: - Metadata Extension (BEP 9)
    private var peerSupportsMetadata = false
    private var receivedExtHandshake = false
    private var utMetadataID: UInt8 = 0
    private var metadataSize: Int = 0
    private var metadataPieces: [Int: Data] = [:]
    private var extHandshakeCont: CheckedContinuation<Void, Error>?
    private var metadataContinuation: CheckedContinuation<Data, Error>?
    private var metadataRequestedPieces = Set<Int>()

    public private(set) var downloadedBytes: Int64 = 0
    public private(set) var uploadedBytes: Int64 = 0

    private var keepAliveTask: Task<Void, Never>?
    public var peerBitfield: [Bool] { bitfield }

    private typealias PieceKey = (index: UInt32, begin: UInt32)
    private var pendingPiece: (key: PieceKey, continuation: CheckedContinuation<Data, Error>)?

    public init(host: String, port: UInt16, infoHash: Data, localPeerID: Data) {
        self.host = host
        self.port = port
        self.infoHash = infoHash
        self.localPeerID = localPeerID
    }

    // MARK: - Connect & Handshake
    public func connect() async throws {
        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )
        self.connection = conn

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    cont.resume()
                case .failed(let err):
                    cont.resume(throwing: err)
                case .cancelled:
                    cont.resume(throwing: PeerError.connectionCancelled)
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .userInitiated))
        }

        try await sendHandshake()
        try await receiveHandshake()
        handshakeDone = true
        startReceiveLoop()
        startKeepAliveTask()
        // Send extended handshake immediately for metadata exchange (BEP 10)
        if peerSupportsMetadata {
            sendOurExtendedHandshake()
        }
    }

    private func startKeepAliveTask() {
        keepAliveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120 * 1_000_000_000)
                var msg = Data()
                msg.append(bigEndian: UInt32(0))
                try? await send(data: msg)
            }
        }
    }

    // MARK: - Handshake
    private func sendHandshake() async throws {
        var handshake = Data()
        let pstr = "BitTorrent protocol"
        handshake.append(UInt8(pstr.count))
        handshake.append(contentsOf: pstr.utf8)
        // Reserved bytes — set bit 20 (byte 2, bit 4 = 0x10) for extension protocol (BEP 10)
        handshake.append(contentsOf: [0, 0, 0x10, 0, 0, 0, 0, 0])
        handshake.append(infoHash)
        handshake.append(localPeerID)
        try await send(data: handshake)
    }

    private func receiveHandshake() async throws {
        let data = try await receive(exactly: 68)
        let pstrLen = Int(data[0])
        guard pstrLen == 19,
              data.count >= 68 else {
            throw PeerError.handshakeFailed
        }
        let receivedInfoHash = data[28..<48]
        guard receivedInfoHash == infoHash else {
            throw PeerError.infoHashMismatch
        }
        // Check if peer supports extensions (bit 20 = byte 2, bit 4 = 0x10)
        let reserved = data[20..<28]
        peerSupportsMetadata = reserved[2] & 0x10 != 0
    }

    // MARK: - Message Loop
    private func startReceiveLoop() {
        Task {
            while true {
                do {
                    let msg = try await receiveMessage()
                    await handleMessage(msg)
                } catch {
                    break
                }
            }
        }
    }

    private func receiveMessage() async throws -> PeerMessage {
        let lenData = try await receive(exactly: 4)
        let length = lenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        if length == 0 { return .keepAlive }
        let payload = try await receive(exactly: Int(length))
        return try PeerMessage.decode(payload)
    }

    private func handleMessage(_ message: PeerMessage) async {
        switch message {
        case .choke:       amChoked = true
        case .unchoke:     amChoked = false
        case .interested:  peerInterested = true
        case .notInterested: peerInterested = false
        case .bitfield(let bits): bitfield = bits
        case .have(let index):
            if index < bitfield.count { bitfield[Int(index)] = true }
        case .piece(let index, let begin, let data):
            if let pending = pendingPiece,
               pending.key.index == index && pending.key.begin == begin {
                pending.continuation.resume(returning: data)
                pendingPiece = nil
            }
        case .extended(let extID, let payload):
            await handleExtendedMessage(extID: extID, payload: payload)
        default: break
        }
    }

    private func handleExtendedMessage(extID: UInt8, payload: Data) async {
        // Extended handshake (BEP 10) — always uses extID = 0
        if extID == 0 {
            var decoder = BencodeDecoder(data: payload)
            guard let dict = try? decoder.decode(),
                  case .dictionary(let ext) = dict else {
                extHandshakeCont?.resume(throwing: PeerError.noMetadataPeer)
                extHandshakeCont = nil
                return
            }
            // Check for ut_metadata support
            if case .dictionary(let m) = ext["m"],
               case .integer(let id) = m["ut_metadata"] {
                utMetadataID = UInt8(id)
                if case .integer(let size) = ext["metadata_size"] {
                    metadataSize = Int(size)
                }
                receivedExtHandshake = true
                extHandshakeCont?.resume()
                extHandshakeCont = nil
            } else {
                receivedExtHandshake = true
                extHandshakeCont?.resume(throwing: PeerError.noMetadataPeer)
                extHandshakeCont = nil
            }
            return
        }

        // Check if this is a ut_metadata message
        guard extID == utMetadataID else { return }
        handleMetadataMessage(payload)
    }

    private func findMetadataBencodeEnd(_ data: Data) -> Int? {
        // Scan for the end of a flat bencoded dictionary (no nested dicts/lists)
        var i = 0
        guard i < data.count, data[i] == UInt8(ascii: "d") else { return nil }
        i += 1 // skip 'd'
        var depth = 1
        while i < data.count && depth > 0 {
            let byte = data[i]
            if byte == UInt8(ascii: "d") {
                depth += 1
                i += 1
            } else if byte == UInt8(ascii: "e") {
                depth -= 1
                i += 1
            } else if byte == UInt8(ascii: "i") {
                // integer: i<digits>e
                i += 1
                while i < data.count && data[i] != UInt8(ascii: "e") { i += 1 }
                i += 1 // skip 'e'
            } else if byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9") {
                // string length prefix
                var len = 0
                while i < data.count && data[i] >= UInt8(ascii: "0") && data[i] <= UInt8(ascii: "9") {
                    len = len * 10 + Int(data[i] - UInt8(ascii: "0"))
                    i += 1
                }
                guard i < data.count, data[i] == UInt8(ascii: ":") else { return nil }
                i += 1 // skip ':'
                i += len // skip string contents
            } else {
                return nil
            }
        }
        return depth == 0 ? i : nil
    }

    private func handleMetadataMessage(_ payload: Data) {
        // bencoded dictionary + metadata piece data
        guard let dictEnd = findMetadataBencodeEnd(payload) else { return }
        let dictData = payload[..<dictEnd]
        let pieceData = payload[dictEnd...]

        var msgDecoder = BencodeDecoder(data: Data(dictData))
        guard let dict = try? msgDecoder.decode(),
              case .dictionary(let msg) = dict,
              case .integer(let msgType) = msg["msg_type"] else { return }

        switch msgType {
        case 0: // request — we don't serve metadata, ignore
            break
        case 1: // data
            guard case .integer(let piece) = msg["piece"], !pieceData.isEmpty else { return }
            metadataPieces[Int(piece)] = Data(pieceData)
            metadataRequestedPieces.remove(Int(piece))

            // Check if we have all pieces
            let totalMetadataBytes = Int(metadataPieces.count) * 16384
            if totalMetadataBytes >= metadataSize {
                // Reassemble metadata
                var full = Data()
                let blockSize = 16384
                let totalPieces = (metadataSize + blockSize - 1) / blockSize
                for i in 0..<totalPieces {
                    if let piece = metadataPieces[i] {
                        full.append(piece)
                    }
                }
                if full.count > metadataSize {
                    full = full.prefix(metadataSize)
                }
                metadataContinuation?.resume(returning: full)
                metadataContinuation = nil
            } else {
                // Request next piece
                requestMetadataPiece()
            }
        case 2: // reject
            metadataContinuation?.resume(throwing: PeerError.metadataRejected)
            metadataContinuation = nil
        default:
            break
        }
    }

    private func requestMetadataPiece() {
        let blockSize = 16384
        let totalPieces = (metadataSize + blockSize - 1) / blockSize

        // Find the next unrequested piece
        for i in 0..<totalPieces {
            if metadataPieces[i] == nil && !metadataRequestedPieces.contains(i) {
                metadataRequestedPieces.insert(i)
                sendMetadataRequest(piece: i)
                return
            }
        }
    }

    private func sendMetadataRequest(piece: Int) {
        let dict: [String: Any] = ["msg_type": 0, "piece": piece]
        let bencoded = BencodeEncoder.encode(dict: dict)
        var msg = Data()
        msg.append(bigEndian: UInt32(2 + bencoded.count))
        msg.append(UInt8(20)) // extended message
        msg.append(utMetadataID)
        msg.append(bencoded)
        // Fire and forget — send directly without awaiting
        Task { try? await send(data: msg) }
    }

    // MARK: - Request a piece
    @discardableResult
    public func requestPiece(index: UInt32, begin: UInt32, length: UInt32) async throws -> Data {
        guard !amChoked else { throw PeerError.choked }
        var msg = Data()
        msg.append(bigEndian: UInt32(13))  // length
        msg.append(UInt8(6))               // type = request
        msg.append(bigEndian: index)
        msg.append(bigEndian: begin)
        msg.append(bigEndian: length)
        try await send(data: msg)

        return try await withThrowingTimeout(seconds: 15) {
            try await withCheckedThrowingContinuation { continuation in
                self.pendingPiece = (key: (index, begin), continuation: continuation)
            }
        }
    }

    public func sendHave(index: UInt32) async throws {
        var msg = Data()
        msg.append(bigEndian: UInt32(5))
        msg.append(UInt8(4)) // have
        msg.append(bigEndian: index)
        try await send(data: msg)
    }

    public func sendInterested() async throws {
        var msg = Data()
        msg.append(bigEndian: UInt32(1))
        msg.append(UInt8(2)) // interested
        try await send(data: msg)
        amInterested = true
    }

    // MARK: - I/O helpers
    private func send(data: Data) async throws {
        guard let conn = connection else { throw PeerError.notConnected }
        return try await withCheckedThrowingContinuation { cont in
            conn.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    private func receive(exactly count: Int) async throws -> Data {
        guard let conn = connection else { throw PeerError.notConnected }
        return try await withCheckedThrowingContinuation { cont in
            conn.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if let error { cont.resume(throwing: error) }
                else if let data { cont.resume(returning: data) }
                else { cont.resume(throwing: PeerError.noData) }
            }
        }
    }

    // MARK: - Extension Handshake (BEP 10)
    private func sendOurExtendedHandshake() {
        let dict: [String: Any] = [
            "m": ["ut_metadata": 2],
            "metadata_size": 0,
            "v": "iTorrentFlow 1.0"
        ]
        let payload = BencodeEncoder.encode(dict: dict)
        var msg = Data()
        msg.append(bigEndian: UInt32(2 + payload.count))
        msg.append(UInt8(20)) // extended message
        msg.append(UInt8(0))  // handshake ID
        msg.append(payload)
        Task { try? await send(data: msg) }
    }

    // MARK: - Fetch Metadata (BEP 9)
    public func fetchMetadata() async throws -> Data {
        guard peerSupportsMetadata else { throw PeerError.noMetadataPeer }

        // Wait for the peer's extended handshake if not already received
        if !receivedExtHandshake {
            sendOurExtendedHandshake()
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                extHandshakeCont = cont
            }
        }

        guard metadataSize > 0 else { throw PeerError.noMetadataPeer }

        // Reset pieces state and start requesting
        metadataPieces = [:]
        metadataRequestedPieces = []
        requestMetadataPiece()

        // Wait for all metadata pieces to arrive with a timeout
        return try await withThrowingTimeout(seconds: 30) {
            try await withCheckedThrowingContinuation { continuation in
                self.metadataContinuation = continuation
            }
        }
    }

    private func withThrowingTimeout<T>(seconds: Int, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw PeerError.metadataRejected
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    public func disconnect() {
        keepAliveTask?.cancel()
        keepAliveTask = nil
        connection?.cancel()
    }

    public var hasPiece: (Int) -> Bool {
        { [bitfield] index in
            index < bitfield.count ? bitfield[index] : false
        }
    }
}

// MARK: - Message Types
public enum PeerMessage {
    case keepAlive
    case choke
    case unchoke
    case interested
    case notInterested
    case have(UInt32)
    case bitfield([Bool])
    case request(index: UInt32, begin: UInt32, length: UInt32)
    case piece(index: UInt32, begin: UInt32, data: Data)
    case cancel(index: UInt32, begin: UInt32, length: UInt32)
    case port(UInt16)
    case extended(extID: UInt8, payload: Data)

    static func decode(_ data: Data) throws -> PeerMessage {
        guard !data.isEmpty else { return .keepAlive }
        let type = data[0]
        switch type {
        case 0: return .choke
        case 1: return .unchoke
        case 2: return .interested
        case 3: return .notInterested
        case 4:
            let index = data[1..<5].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            return .have(index)
        case 5:
            let bits = data[1...].flatMap { byte -> [Bool] in
                (7...0).reversed().map { bit in (byte >> bit) & 1 == 1 }
            }
            return .bitfield(bits)
        case 6:
            let idx = data[1..<5].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let begin = data[5..<9].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let len = data[9..<13].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            return .request(index: idx, begin: begin, length: len)
        case 7:
            let idx = data[1..<5].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let begin = data[5..<9].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            let payload = data[9...]
            return .piece(index: idx, begin: begin, data: Data(payload))
        case 20:
            guard data.count >= 2 else { throw PeerError.unknownMessage(type) }
            let extID = data[1]
            let extPayload = data[2...]
            return .extended(extID: extID, payload: Data(extPayload))
        default:
            throw PeerError.unknownMessage(type)
        }
    }
}

// MARK: - Peer Errors
public enum PeerError: Error, LocalizedError {
    case notConnected, handshakeFailed, infoHashMismatch
    case choked, noData, connectionCancelled, unknownMessage(UInt8)
    case metadataRejected, noMetadataPeer

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Peer not connected"
        case .handshakeFailed: return "BitTorrent handshake failed"
        case .infoHashMismatch: return "Info hash mismatch"
        case .choked: return "Peer has choked us"
        case .noData: return "No data received"
        case .connectionCancelled: return "Connection cancelled"
        case .unknownMessage(let t): return "Unknown message type: \(t)"
        case .metadataRejected: return "Peer rejected metadata request"
        case .noMetadataPeer: return "No peer supports metadata exchange"
        }
    }
}

// MARK: - Data Helpers
private extension Data {
    mutating func append<T: FixedWidthInteger>(bigEndian value: T) {
        var v = value.bigEndian
        self.append(Data(bytes: &v, count: MemoryLayout<T>.size))
    }
}
