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

    public private(set) var downloadedBytes: Int64 = 0
    public private(set) var uploadedBytes: Int64 = 0

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
    }

    // MARK: - Handshake
    private func sendHandshake() async throws {
        var handshake = Data()
        let pstr = "BitTorrent protocol"
        handshake.append(UInt8(pstr.count))
        handshake.append(contentsOf: pstr.utf8)
        handshake.append(contentsOf: [UInt8](repeating: 0, count: 8)) // reserved
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
        default: break
        }
    }

    // MARK: - Request a piece
    public func requestPiece(index: UInt32, begin: UInt32, length: UInt32) async throws {
        guard !amChoked else { throw PeerError.choked }
        var msg = Data()
        msg.append(bigEndian: UInt32(13))  // length
        msg.append(UInt8(6))               // type = request
        msg.append(bigEndian: index)
        msg.append(bigEndian: begin)
        msg.append(bigEndian: length)
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

    public func disconnect() {
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
        default:
            throw PeerError.unknownMessage(type)
        }
    }
}

// MARK: - Peer Errors
public enum PeerError: Error, LocalizedError {
    case notConnected, handshakeFailed, infoHashMismatch
    case choked, noData, connectionCancelled, unknownMessage(UInt8)

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Peer not connected"
        case .handshakeFailed: return "BitTorrent handshake failed"
        case .infoHashMismatch: return "Info hash mismatch"
        case .choked: return "Peer has choked us"
        case .noData: return "No data received"
        case .connectionCancelled: return "Connection cancelled"
        case .unknownMessage(let t): return "Unknown message type: \(t)"
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
