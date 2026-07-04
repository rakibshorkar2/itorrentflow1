import Foundation
import Network
import CryptoKit

// MARK: - DHT Peer Discovery (BEP 5 / BEP 42)
/// Minimal Kademlia-based DHT client for finding peers without a tracker
public actor DHTPeerDiscovery {
    private let bootstrapNodes = [
        ("router.bittorrent.com", UInt16(6881)),
        ("dht.transmissionbt.com", UInt16(6881)),
        ("router.utorrent.com", UInt16(6881))
    ]

    private var nodeID: Data
    private var routingTable: [DHTNode] = []
    private var transactionCounter: UInt16 = 0

    public init() {
        var id = Data(repeating: 0, count: 20)
        id.withUnsafeMutableBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, 20, base)
        }
        self.nodeID = id
    }

    // MARK: - Find Peers
    public func findPeers(infoHash: Data) async throws -> [(String, UInt16)] {
        try await bootstrap()

        // Query closest nodes for peers
        var allPeers: [(String, UInt16)] = []
        let closest = routingTable.sorted { lhs, rhs in
            xorDistance(lhs.id, infoHash) < xorDistance(rhs.id, infoHash)
        }.prefix(8)

        for node in closest {
            do {
                let peers = try await queryGetPeers(node: node, infoHash: infoHash)
                allPeers.append(contentsOf: peers)
            } catch {
                continue
            }
        }
        return Array(Set(allPeers.map { "\($0.0):\($0.1)" }).compactMap { str in
            let parts = str.split(separator: ":"); guard parts.count == 2 else { return nil }
            return (String(parts[0]), UInt16(parts[1]) ?? 6881)
        })
    }

    // MARK: - Bootstrap
    private func bootstrap() async throws {
        guard routingTable.isEmpty else { return }

        for (host, port) in bootstrapNodes {
            let node = DHTNode(id: Data(repeating: 0, count: 20), host: host, port: port)
            if let nodes = try? await queryFindNode(node: node, target: nodeID) {
                routingTable.append(contentsOf: nodes)
            }
        }

        // Find closer nodes to ourselves to fill the routing table
        let closer = routingTable.sorted { lhs, rhs in
            xorDistance(lhs.id, nodeID) < xorDistance(rhs.id, nodeID)
        }.prefix(4)

        for node in closer {
            if let nodes = try? await queryFindNode(node: node, target: nodeID) {
                for n in nodes where !routingTable.contains(where: { $0.id == n.id }) {
                    routingTable.append(n)
                }
            }
        }

        // Cap routing table
        if routingTable.count > 50 {
            routingTable = Array(routingTable.prefix(50))
        }
    }

    // MARK: - KRPC Queries
    private func queryGetPeers(node: DHTNode, infoHash: Data) async throws -> [(String, UInt16)] {
        let tid = nextTransactionID()
        let args: [String: Any] = [
            "id": Data(nodeID),
            "info_hash": Data(infoHash)
        ]
        let query = makeQuery(tid: tid, method: "get_peers", args: args)

        // Setup UDP
        let conn = NWConnection(
            host: NWEndpoint.Host(node.host),
            port: NWEndpoint.Port(rawValue: node.port)!,
            using: .udp
        )
        conn.start(queue: .global())

        return try await withThrowingTimeout(seconds: 5) {
            try await withCheckedThrowingContinuation { continuation in
                conn.send(content: query, completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 65535) { data, _, _, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let data {
                            let peers = self.parseGetPeersResponse(data)
                            continuation.resume(returning: peers)
                        } else {
                            continuation.resume(returning: [])
                        }
                        conn.cancel()
                    }
                })
            }
        }
    }

    private func queryFindNode(node: DHTNode, target: Data) async throws -> [DHTNode] {
        let tid = nextTransactionID()
        let args: [String: Any] = [
            "id": Data(nodeID),
            "target": Data(target)
        ]
        let query = makeQuery(tid: tid, method: "find_node", args: args)

        let conn = NWConnection(
            host: NWEndpoint.Host(node.host),
            port: NWEndpoint.Port(rawValue: node.port)!,
            using: .udp
        )
        conn.start(queue: .global())

        return try await withThrowingTimeout(seconds: 5) {
            try await withCheckedThrowingContinuation { continuation in
                conn.send(content: query, completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 65535) { data, _, _, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let data {
                            let nodes = self.parseFindNodeResponse(data)
                            continuation.resume(returning: nodes)
                        } else {
                            continuation.resume(returning: [])
                        }
                        conn.cancel()
                    }
                })
            }
        }
    }

    // MARK: - KRPC Message Building
    private func makeQuery(tid: String, method: String, args: [String: Any]) -> Data {
        let dict: [String: Any] = [
            "t": tid,
            "y": "q",
            "q": method,
            "a": args
        ]
        return BencodeEncoder.encode(dict: dict)
    }

    private func nextTransactionID() -> String {
        transactionCounter += 1
        return String(format: "%02x", transactionCounter)
    }

    // MARK: - Response Parsing
    private func parseGetPeersResponse(_ data: Data) -> [(String, UInt16)] {
        var decoder = BencodeDecoder(data: data)
        guard let root = try? decoder.decode(),
              case .dictionary(let dict) = root,
              case .dictionary(let r) = dict["r"] else { return [] }

        // Compact peers format (6 bytes each)
        if case .string(let compact) = r["values"] {
            return parseCompactPeers(compact)
        }
        // Nodes for recursive lookup (we skip this for simplicity)
        if case .string(let nodes) = r["nodes"] {
            return parseCompactPeers(nodes) // fallback — extract IPs from node format
        }
        return []
    }

    private func parseFindNodeResponse(_ data: Data) -> [DHTNode] {
        var decoder = BencodeDecoder(data: data)
        guard let root = try? decoder.decode(),
              case .dictionary(let dict) = root,
              case .dictionary(let r) = dict["r"],
              case .string(let nodesData) = r["nodes"] else { return [] }

        return parseCompactNodes(nodesData)
    }

    private func parseCompactPeers(_ data: Data) -> [(String, UInt16)] {
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

    private func parseCompactNodes(_ data: Data) -> [DHTNode] {
        var nodes: [DHTNode] = []
        let bytes = Array(data)
        var i = 0
        while i + 26 <= bytes.count {
            let id = Data(bytes[i..<i+20])
            let ip = "\(bytes[i+20]).\(bytes[i+21]).\(bytes[i+22]).\(bytes[i+23])"
            let port = UInt16(bytes[i+24]) << 8 | UInt16(bytes[i+25])
            nodes.append(DHTNode(id: id, host: ip, port: port))
            i += 26
        }
        return nodes
    }

    // MARK: - Helpers
    private func xorDistance(_ a: Data, _ b: Data) -> Data {
        Data(zip(a, b).map { $0 ^ $1 })
    }

    private func withThrowingTimeout<T>(seconds: Int, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                throw DHTError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - DHT Errors
enum DHTError: Error {
    case timeout
}

// MARK: - DHT Node
private struct DHTNode {
    let id: Data
    let host: String
    let port: UInt16
}
