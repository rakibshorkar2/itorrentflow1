import Foundation

// MARK: - Search Result Model
public struct TorrentSearchResult: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let magnetLink: String?
    public let torrentFileURL: String?
    public let seeders: Int
    public let leechers: Int
    public let size: Int64
    public let category: String
    public let uploadDate: String
    public let uploader: String
    public let providerName: String

    public init(
        id: UUID = UUID(),
        name: String,
        magnetLink: String? = nil,
        torrentFileURL: String? = nil,
        seeders: Int = 0,
        leechers: Int = 0,
        size: Int64 = 0,
        category: String = "",
        uploadDate: String = "",
        uploader: String = "",
        providerName: String = ""
    ) {
        self.id = id; self.name = name; self.magnetLink = magnetLink
        self.torrentFileURL = torrentFileURL; self.seeders = seeders
        self.leechers = leechers; self.size = size; self.category = category
        self.uploadDate = uploadDate; self.uploader = uploader
        self.providerName = providerName
    }

    public var formattedSize: String {
        size > 0 ? ByteCountFormatter.string(fromByteCount: size, countStyle: .file) : "Unknown"
    }

    public var healthColor: String {
        if seeders > 50 { return "green" }
        if seeders > 10 { return "yellow" }
        return "red"
    }
}

// MARK: - Search Provider Protocol
public protocol TorrentSearchProvider {
    var name: String { get }
    var baseURL: String { get }
    func search(query: String, category: SearchCategory, page: Int) async throws -> [TorrentSearchResult]
}

public enum SearchCategory: String, CaseIterable {
    case all = "All"
    case movies = "Movies"
    case tvShows = "TV Shows"
    case music = "Music"
    case games = "Games"
    case software = "Software"
    case books = "Books"
    case other = "Other"
}

// MARK: - The Pirate Bay Provider (via API proxy)
public struct TPBSearchProvider: TorrentSearchProvider {
    public let name = "ThePirateBay"
    public let baseURL = "https://apibay.org"

    private let session = URLSession.shared

    public func search(query: String, category: SearchCategory, page: Int) async throws -> [TorrentSearchResult] {
        let catID = tpbCategory(for: category)
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(baseURL)/q.php?q=\(encoded)&cat=\(catID)") else {
            throw SearchError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SearchError.httpError
        }

        struct TPBResult: Codable {
            let id: String
            let name: String
            let info_hash: String
            let leechers: String
            let seeders: String
            let num_files: String
            let size: String
            let username: String
            let added: String
            let status: String
            let category: String
        }

        let results = try JSONDecoder().decode([TPBResult].self, from: data)

        // Filter out "No results" response
        if results.first?.name == "No results returned" { return [] }

        return results.map { r in
            let seeders = Int(r.seeders) ?? 0
            let leechers = Int(r.leechers) ?? 0
            let size = Int64(r.size) ?? 0
            let magnet = buildMagnet(infoHash: r.info_hash, name: r.name)

            return TorrentSearchResult(
                name: r.name,
                magnetLink: magnet,
                seeders: seeders,
                leechers: leechers,
                size: size,
                category: r.category,
                uploadDate: formatDate(r.added),
                uploader: r.username,
                providerName: name
            )
        }
    }

    private func buildMagnet(infoHash: String, name: String) -> String {
        let trackers = [
            "udp://tracker.openbittorrent.com:80",
            "udp://tracker.opentrackr.org:1337/announce",
            "udp://open.stealth.si:80/announce",
            "udp://tracker.torrent.eu.org:451/announce"
        ]
        var magnet = "magnet:?xt=urn:btih:\(infoHash)"
        if let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            magnet += "&dn=\(enc)"
        }
        for tr in trackers {
            if let enc = tr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                magnet += "&tr=\(enc)"
            }
        }
        return magnet
    }

    private func tpbCategory(for category: SearchCategory) -> String {
        switch category {
        case .all: return "0"
        case .movies: return "200"
        case .tvShows: return "205"
        case .music: return "100"
        case .games: return "400"
        case .software: return "300"
        case .books: return "601"
        case .other: return "600"
        }
    }

    private func formatDate(_ unixString: String) -> String {
        guard let ts = Double(unixString) else { return unixString }
        let date = Date(timeIntervalSince1970: ts)
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 1337x Provider
public struct LeetXSearchProvider: TorrentSearchProvider {
    public let name = "1337x"
    public let baseURL = "https://1337x.to"

    public func search(query: String, category: SearchCategory, page: Int) async throws -> [TorrentSearchResult] {
        // 1337x requires scraping — return empty for now, real impl uses HTMLParser
        return []
    }
}

// MARK: - Torrent Search Service
@MainActor
public final class TorrentSearchService: ObservableObject {
    public static let shared = TorrentSearchService()

    private let providers: [TorrentSearchProvider]

    private init() {
        providers = [TPBSearchProvider(), LeetXSearchProvider()]
    }

    public func search(
        query: String,
        category: SearchCategory = .all,
        page: Int = 1
    ) async throws -> [TorrentSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        var allResults: [TorrentSearchResult] = []

        await withTaskGroup(of: [TorrentSearchResult].self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        return try await provider.search(query: query, category: category, page: page)
                    } catch {
                        return []
                    }
                }
            }
            for await results in group {
                allResults.append(contentsOf: results)
            }
        }

        // Sort by seeders
        return allResults.sorted { $0.seeders > $1.seeders }
    }
}

// MARK: - Errors
public enum SearchError: Error, LocalizedError {
    case invalidURL, httpError, parseError

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid search URL"
        case .httpError: return "Search request failed"
        case .parseError: return "Failed to parse search results"
        }
    }
}
