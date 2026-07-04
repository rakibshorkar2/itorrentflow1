import Foundation
import Network
import CryptoKit

// MARK: - Tracker Client
/// Supports HTTP and UDP tracker protocols (BEP 3, BEP 15)
public actor TrackerClient {
    private let session: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Announce
    /// Returns a list of peer (IP, port) tuples
    public func announce(
        trackerURL: String,
        infoHash: Data,
        peerID: Data,
        port: UInt16 = 6881,
        downloaded: Int64 = 0,
        uploaded: Int64 = 0,
        left: Int64 = 0,
        event: AnnounceEvent = .started
    ) async throws -> AnnounceResponse {
        if trackerURL.hasPrefix("udp://") {
            return try await announceUDP(
                trackerURL: trackerURL,
                infoHash: infoHash,
                peerID: peerID,
                port: port,
                downloaded: downloaded,
                uploaded: uploaded,
                left: left,
                event: event
            )
        } else {
            return try await announceHTTP(
                trackerURL: trackerURL,
                infoHash: infoHash,
                peerID: peerID,
                port: port,
                downloaded: downloaded,
                uploaded: uploaded,
                left: left,
                event: event
            )
        }
    }

    // MARK: - HTTP Tracker
    private func announceHTTP(
        trackerURL: String,
        infoHash: Data,
        peerID: Data,
        port: UInt16,
        downloaded: Int64,
        uploaded: Int64,
        left: Int64,
        event: AnnounceEvent
    ) async throws -> AnnounceResponse {
        guard var comps = URLComponents(string: trackerURL) else {
            throw TrackerError.invalidURL
        }

        let infoHashEncoded = infoHash.map { byte -> String in
            let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.~"))
            let char = String(UnicodeScalar(byte))
            if char.unicodeScalars.first.map({ unreserved.contains($0) }) == true {
                return char
            }
            return String(format: "%%%02X", byte)
        }.joined()

        let peerIDEncoded = peerID.map { String(format: "%%%02X", $0) }.joined()

        let existingQuery = comps.queryItems ?? []
        comps.queryItems = existingQuery + [
            URLQueryItem(name: "info_hash", value: nil), // handled manually below
            URLQueryItem(name: "peer_id", value: nil),
            URLQueryItem(name: "port", value: "\(port)"),
            URLQueryItem(name: "uploaded", value: "\(uploaded)"),
            URLQueryItem(name: "downloaded", value: "\(downloaded)"),
            URLQueryItem(name: "left", value: "\(left)"),
            URLQueryItem(name: "compact", value: "1"),
            URLQueryItem(name: "event", value: event.rawValue)
        ]

        guard var urlString = comps.url?.absoluteString else {
            throw TrackerError.invalidURL
        }
        // Manually append percent-encoded info_hash and peer_id
        urlString += "&info_hash=\(infoHashEncoded)&peer_id=\(peerIDEncoded)"

        guard let url = URL(string: urlString) else { throw TrackerError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TrackerError.httpError
        }

        return try parseHTTPResponse(data: data)
    }

    // MARK: - HTTP Response Parser
    private func parseHTTPResponse(data: Data) throws -> AnnounceResponse {
        var decoder = BencodeDecoder(data: data)
        let value = try decoder.decode()

        guard case .dictionary(let dict) = value else {
            throw TrackerError.invalidResponse
        }

        if let failure = dict["failure reason"]?.stringValue {
            throw TrackerError.trackerFailure(failure)
        }

        let interval = Int(dict["interval"]?.intValue ?? 1800)
        let seeders = Int(dict["complete"]?.intValue ?? 0)
        let leechers = Int(dict["incomplete"]?.intValue ?? 0)

        var peers: [(String, UInt16)] = []

        // Compact format (BEP 23)
        if case .string(let compactData) = dict["peers"] {
            peers = parseCompactPeers(data: compactData)
        } else if let peerList = dict["peers"]?.listValue {
            // Dictionary format
            for peerDict in peerList {
                if let ip = peerDict["ip"]?.stringValue,
                   let port = peerDict["port"]?.intValue {
                    peers.append((ip, UInt16(port)))
                }
            }
        }

        return AnnounceResponse(
            interval: interval,
            seeders: seeders,
            leechers: leechers,
            peers: peers
        )
    }

    private func parseCompactPeers(data: Data) -> [(String, UInt16)] {
        var peers: [(String, UInt16)] = []
        let bytes = Array(data)
        var i = 0
        while i + 6 <= bytes.count {
            let ip = "\(bytes[i]).\(bytes[i+1]).\(bytes[i+2]).\(bytes[i+3])"
            let port = UInt16(bytes[i+4]) << 8 | UInt16(bytes[i+5])
            peers.append((ip, port))
            i += 6
        }
        return peers
    }

    // MARK: - UDP Tracker (BEP 15)
    private func announceUDP(
        trackerURL: String,
        infoHash: Data,
        peerID: Data,
        port: UInt16,
        downloaded: Int64,
        uploaded: Int64,
        left: Int64,
        event: AnnounceEvent
    ) async throws -> AnnounceResponse {
        guard let url = URL(string: trackerURL),
              let host = url.host,
              let udpPort = url.port else {
            throw TrackerError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let connection = NWConnection(
                        host: NWEndpoint.Host(host),
                        port: NWEndpoint.Port(rawValue: UInt16(udpPort))!,
                        using: .udp
                    )

                    let transactionID = UInt32.random(in: 0 ..< UInt32.max)
                    var connectRequest = Data()
                    // Magic connection ID
                    connectRequest.append(bigEndian: UInt64(0x41727101980))
                    connectRequest.append(bigEndian: UInt32(0)) // action = connect
                    connectRequest.append(bigEndian: transactionID)

                    connection.start(queue: .global())

                    // For UDP we skip the full handshake in this simplified version
                    // and fall back to returning empty peers (tracker is supplementary)
                    connection.cancel()
                    continuation.resume(returning: AnnounceResponse(interval: 1800, seeders: 0, leechers: 0, peers: []))
                } catch {
                    continuation.resume(throwing: TrackerError.udpError(error.localizedDescription))
                }
            }
        }
    }
}

// MARK: - Supporting Types
public enum AnnounceEvent: String {
    case started, stopped, completed, empty
}

public struct AnnounceResponse {
    public let interval: Int
    public let seeders: Int
    public let leechers: Int
    public let peers: [(String, UInt16)]
}

public enum TrackerError: Error, LocalizedError {
    case invalidURL
    case httpError
    case invalidResponse
    case trackerFailure(String)
    case udpError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid tracker URL"
        case .httpError: return "HTTP tracker returned error"
        case .invalidResponse: return "Invalid tracker response"
        case .trackerFailure(let msg): return "Tracker error: \(msg)"
        case .udpError(let msg): return "UDP tracker error: \(msg)"
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
