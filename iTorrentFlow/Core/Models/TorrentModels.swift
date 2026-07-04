import Foundation
import SwiftUI

// MARK: - Torrent Status
public enum TorrentStatus: Equatable {
    case stopped
    case connecting
    case downloading
    case seeding
    case paused
    case completed
    case error(String)
    case fetchingMetadata

    public var label: String {
        switch self {
        case .stopped: return "Stopped"
        case .connecting: return "Connecting..."
        case .downloading: return "Downloading"
        case .seeding: return "Seeding"
        case .paused: return "Paused"
        case .completed: return "Complete"
        case .error(let msg): return "Error: \(msg)"
        case .fetchingMetadata: return "Fetching Metadata..."
        }
    }

    public var icon: String {
        switch self {
        case .stopped: return "stop.circle.fill"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .downloading: return "arrow.down.circle.fill"
        case .seeding: return "arrow.up.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .fetchingMetadata: return "magnifyingglass.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .stopped: return .secondary
        case .connecting: return .orange
        case .downloading: return .blue
        case .seeding: return .green
        case .paused: return .yellow
        case .completed: return .mint
        case .error: return .red
        case .fetchingMetadata: return .purple
        }
    }

    public var isActive: Bool {
        switch self {
        case .downloading, .seeding, .connecting, .fetchingMetadata: return true
        default: return false
        }
    }

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }

    public static func == (lhs: TorrentStatus, rhs: TorrentStatus) -> Bool {
        switch (lhs, rhs) {
        case (.stopped, .stopped), (.connecting, .connecting),
             (.downloading, .downloading), (.seeding, .seeding),
             (.paused, .paused), (.completed, .completed),
             (.fetchingMetadata, .fetchingMetadata): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Torrent Item (UI Model)
public struct TorrentItem: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var infoHashHex: String
    public var totalSize: Int64
    public var downloadedSize: Int64
    public var progress: Double
    public var status: TorrentItemStatus
    public var addedDate: Date
    public var trackers: [String]
    public var fileCount: Int
    public var category: TorrentCategory
    public var saveDirectory: String

    public init(
        id: UUID = UUID(),
        name: String,
        infoHashHex: String,
        totalSize: Int64 = 0,
        downloadedSize: Int64 = 0,
        progress: Double = 0,
        status: TorrentItemStatus = .stopped,
        addedDate: Date = Date(),
        trackers: [String] = [],
        fileCount: Int = 0,
        category: TorrentCategory = .general,
        saveDirectory: String = ""
    ) {
        self.id = id; self.name = name; self.infoHashHex = infoHashHex
        self.totalSize = totalSize; self.downloadedSize = downloadedSize
        self.progress = progress; self.status = status; self.addedDate = addedDate
        self.trackers = trackers; self.fileCount = fileCount
        self.category = category; self.saveDirectory = saveDirectory
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public var formattedDownloaded: String {
        ByteCountFormatter.string(fromByteCount: downloadedSize, countStyle: .file)
    }
}

public enum TorrentItemStatus: String, Codable {
    case stopped, connecting, downloading, seeding, paused, completed, error

    public func toTorrentStatus() -> TorrentStatus {
        switch self {
        case .stopped: return .stopped
        case .connecting: return .connecting
        case .downloading: return .downloading
        case .seeding: return .seeding
        case .paused: return .paused
        case .completed: return .completed
        case .error: return .error("Unknown")
        }
    }
}

public enum TorrentCategory: String, Codable, CaseIterable {
    case general = "General"
    case movies = "Movies"
    case tvShows = "TV Shows"
    case music = "Music"
    case software = "Software"
    case games = "Games"
    case books = "Books"
    case other = "Other"

    public var icon: String {
        switch self {
        case .general: return "tray.fill"
        case .movies: return "film.fill"
        case .tvShows: return "tv.fill"
        case .music: return "music.note"
        case .software: return "app.fill"
        case .games: return "gamecontroller.fill"
        case .books: return "book.fill"
        case .other: return "archivebox.fill"
        }
    }
}

// MARK: - Peer Info
public struct PeerInfo: Identifiable, Codable {
    public let id: UUID
    public var ip: String
    public var port: UInt16
    public var client: String
    public var downloadSpeed: Int64
    public var uploadSpeed: Int64
    public var progress: Double
    public var flags: String

    public init(id: UUID = UUID(), ip: String, port: UInt16, client: String = "",
                downloadSpeed: Int64 = 0, uploadSpeed: Int64 = 0,
                progress: Double = 0, flags: String = "") {
        self.id = id; self.ip = ip; self.port = port; self.client = client
        self.downloadSpeed = downloadSpeed; self.uploadSpeed = uploadSpeed
        self.progress = progress; self.flags = flags
    }
}

