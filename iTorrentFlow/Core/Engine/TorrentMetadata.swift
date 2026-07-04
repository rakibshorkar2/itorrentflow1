import Foundation
import CryptoKit

// MARK: - TorrentMetadata
/// Parses a .torrent file into structured metadata
public struct TorrentMetadata {
    public let infoHash: Data          // 20-byte SHA1 of the bencoded "info" dict
    public let name: String
    public let totalSize: Int64
    public let pieceLength: Int
    public let pieces: [Data]          // Array of 20-byte SHA1 hashes (one per piece)
    public let files: [TorrentFileEntry]
    public let trackerURLs: [String]
    public let webSeedURLs: [String]
    public let isPrivate: Bool
    public let comment: String?
    public let createdBy: String?
    public let creationDate: Date?

    // MARK: - Parse from data
    public static func parse(from data: Data) throws -> TorrentMetadata {
        var decoder = BencodeDecoder(data: data)
        let root = try decoder.decode()

        guard case .dictionary(let rootDict) = root else {
            throw TorrentParseError.invalidRoot
        }

        // Extract trackers
        var trackers: [String] = []
        if let announce = rootDict["announce"]?.stringValue {
            trackers.append(announce)
        }
        if let announceList = rootDict["announce-list"]?.listValue {
            for tier in announceList {
                if let tierList = tier.listValue {
                    for url in tierList {
                        if let urlStr = url.stringValue { trackers.append(urlStr) }
                    }
                }
            }
        }
        trackers = Array(Set(trackers)) // Deduplicate

        guard let infoValue = rootDict["info"] else {
            throw TorrentParseError.missingInfo
        }
        guard case .dictionary(let info) = infoValue else {
            throw TorrentParseError.invalidInfo
        }

        // Compute info hash from re-encoded info dict
        let infoData = BencodeEncoder.encode(infoValue)
        let infoHash = Data(Insecure.SHA1.hash(data: infoData))

        guard let name = info["name"]?.stringValue ?? info["name.utf-8"]?.stringValue else {
            throw TorrentParseError.missingName
        }

        guard let pieceLengthRaw = info["piece length"]?.intValue else {
            throw TorrentParseError.missingPieceLength
        }
        let pieceLength = Int(pieceLengthRaw)

        guard case .string(let piecesData) = info["pieces"] else {
            throw TorrentParseError.missingPieces
        }
        var pieces: [Data] = []
        var offset = 0
        while offset + 20 <= piecesData.count {
            pieces.append(piecesData[offset ..< offset + 20])
            offset += 20
        }

        let isPrivate = (info["private"]?.intValue ?? 0) == 1

        // Parse files
        var files: [TorrentFileEntry] = []
        var totalSize: Int64 = 0

        if let fileList = info["files"]?.listValue {
            // Multi-file torrent
            for fileItem in fileList {
                guard let fileDict = fileItem.dictValue,
                      let length = fileDict["length"]?.intValue,
                      let pathList = fileDict["path"]?.listValue else { continue }
                let path = pathList.compactMap { $0.stringValue }.joined(separator: "/")
                let fileEntry = TorrentFileEntry(
                    path: "\(name)/\(path)",
                    length: length,
                    priority: .normal
                )
                files.append(fileEntry)
                totalSize += length
            }
        } else if let length = info["length"]?.intValue {
            // Single-file torrent
            let ext = (name as NSString).pathExtension
            files.append(TorrentFileEntry(path: name, length: length, priority: .normal))
            totalSize = length
            _ = ext
        }

        return TorrentMetadata(
            infoHash: infoHash,
            name: name,
            totalSize: totalSize,
            pieceLength: pieceLength,
            pieces: pieces,
            files: files,
            trackerURLs: trackers,
            webSeedURLs: [],
            isPrivate: isPrivate,
            comment: rootDict["comment"]?.stringValue,
            createdBy: rootDict["created by"]?.stringValue,
            creationDate: rootDict["creation date"]?.intValue.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        )
    }

    public var infoHashHex: String {
        infoHash.map { String(format: "%02x", $0) }.joined()
    }

    public var magnetLink: String {
        var comps = URLComponents()
        comps.scheme = "magnet"
        comps.queryItems = [
            URLQueryItem(name: "xt", value: "urn:btih:\(infoHashHex)"),
            URLQueryItem(name: "dn", value: name)
        ]
        for tracker in trackerURLs.prefix(3) {
            comps.queryItems?.append(URLQueryItem(name: "tr", value: tracker))
        }
        return comps.url?.absoluteString ?? ""
    }
}

// MARK: - File Entry
public struct TorrentFileEntry: Identifiable, Codable {
    public let id: UUID
    public let path: String
    public let length: Int64
    public var priority: FilePriority

    public init(id: UUID = UUID(), path: String, length: Int64, priority: FilePriority) {
        self.id = id
        self.path = path
        self.length = length
        self.priority = priority
    }

    public var name: String { (path as NSString).lastPathComponent }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: length, countStyle: .file)
    }
}

public enum FilePriority: Int, Codable, CaseIterable {
    case skip = 0
    case low = 1
    case normal = 4
    case high = 7

    public var label: String {
        switch self {
        case .skip: return "Skip"
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }
}

// MARK: - Parse Errors
public enum TorrentParseError: Error, LocalizedError {
    case invalidRoot, missingInfo, invalidInfo, missingName, missingPieceLength, missingPieces

    public var errorDescription: String? {
        switch self {
        case .invalidRoot: return "Invalid torrent: expected dictionary at root"
        case .missingInfo: return "Torrent missing 'info' dictionary"
        case .invalidInfo: return "Invalid 'info' dictionary"
        case .missingName: return "Torrent missing name"
        case .missingPieceLength: return "Torrent missing piece length"
        case .missingPieces: return "Torrent missing piece hashes"
        }
    }
}
