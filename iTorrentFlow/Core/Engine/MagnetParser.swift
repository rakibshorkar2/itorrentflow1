import Foundation

// MARK: - Magnet URI Parser
/// Decodes magnet: links into structured data
public struct MagnetLink {
    public let infoHash: String          // hex or base32
    public let displayName: String?
    public let trackers: [String]
    public let webSeeds: [String]
    public let exactLength: Int64?

    // MARK: - Parse
    public static func parse(from urlString: String) throws -> MagnetLink {
        guard urlString.lowercased().hasPrefix("magnet:?") else {
            throw MagnetError.notMagnetLink
        }

        // URLComponents can't handle magnet: directly, so we normalize it
        let normalized = urlString.replacingOccurrences(of: "magnet:?", with: "https://placeholder.local/?")
        guard let comps = URLComponents(string: normalized) else {
            throw MagnetError.invalidURL
        }

        let params = Dictionary(
            grouping: comps.queryItems ?? [],
            by: { $0.name }
        ).mapValues { items in items.compactMap { $0.value } }

        // Extract xt= (exact topic = info hash)
        guard let xtValues = params["xt"], !xtValues.isEmpty else {
            throw MagnetError.missingInfoHash
        }

        var infoHash: String?
        for xt in xtValues {
            if xt.lowercased().hasPrefix("urn:btih:") {
                infoHash = String(xt.dropFirst(9)).lowercased()
                // If base32, convert to hex
                if let hash = infoHash, hash.count == 32 {
                    infoHash = base32ToHex(hash)
                }
                break
            }
        }

        guard let hash = infoHash else {
            throw MagnetError.missingInfoHash
        }

        let displayName = params["dn"]?.first?.removingPercentEncoding
        let trackers = (params["tr"] ?? []).compactMap { $0.removingPercentEncoding }
        let webSeeds = (params["ws"] ?? []).compactMap { $0.removingPercentEncoding }
        let exactLength = params["xl"]?.first.flatMap { Int64($0) }

        return MagnetLink(
            infoHash: hash,
            displayName: displayName,
            trackers: trackers,
            webSeeds: webSeeds,
            exactLength: exactLength
        )
    }

    // MARK: - Base32 → Hex
    private static func base32ToHex(_ base32: String) -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let upper = base32.uppercased()
        var bits: [UInt8] = []

        for char in upper {
            guard let idx = alphabet.firstIndex(of: char) else { continue }
            let val = UInt8(alphabet.distance(from: alphabet.startIndex, to: idx))
            for bit in stride(from: 4, through: 0, by: -1) {
                bits.append((val >> bit) & 1)
            }
        }

        var hex = ""
        var i = 0
        while i + 8 <= bits.count {
            let byte = bits[i..<i+8].reduce(0) { ($0 << 1) | $1 }
            hex += String(format: "%02x", byte)
            i += 8
        }
        return hex
    }

    /// Creates a magnet URL string
    public func toURL() -> URL? {
        var components = "magnet:?xt=urn:btih:\(infoHash)"
        if let name = displayName?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            components += "&dn=\(name)"
        }
        for tracker in trackers {
            if let enc = tracker.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                components += "&tr=\(enc)"
            }
        }
        return URL(string: components)
    }

    public var infoHashData: Data? {
        var data = Data()
        var hex = infoHash
        while hex.count >= 2 {
            let pair = String(hex.prefix(2))
            hex = String(hex.dropFirst(2))
            guard let byte = UInt8(pair, radix: 16) else { return nil }
            data.append(byte)
        }
        return data.count == 20 ? data : nil
    }
}

// MARK: - Errors
public enum MagnetError: Error, LocalizedError {
    case notMagnetLink
    case invalidURL
    case missingInfoHash

    public var errorDescription: String? {
        switch self {
        case .notMagnetLink: return "Not a magnet link"
        case .invalidURL: return "Invalid magnet URL"
        case .missingInfoHash: return "Magnet link missing info hash (xt parameter)"
        }
    }
}
