import ActivityKit
import Foundation

// MARK: - Live Activity Attributes
/// Defines the static and dynamic content of the Dynamic Island + Lock Screen widget
@available(iOS 16.1, *)
public struct TorrentLiveActivityAttributes: ActivityAttributes {
    public typealias ContentState = TorrentDownloadState

    // Static data (doesn't change during activity lifetime)
    public let torrentName: String
    public let torrentID: String

    public init(torrentName: String, torrentID: String) {
        self.torrentName = torrentName
        self.torrentID = torrentID
    }

    // MARK: - Dynamic State
    public struct TorrentDownloadState: Codable, Hashable {
        /// 0.0 – 1.0
        public var progress: Double
        /// Bytes per second
        public var downloadSpeed: Int64
        /// Bytes per second
        public var uploadSpeed: Int64
        /// Total bytes downloaded
        public var downloadedBytes: Int64
        /// Total bytes in torrent
        public var totalBytes: Int64
        /// Human-readable status label
        public var statusLabel: String
        /// Number of connected peers
        public var connectedPeers: Int
        /// Is the torrent paused?
        public var isPaused: Bool

        public init(
            progress: Double = 0,
            downloadSpeed: Int64 = 0,
            uploadSpeed: Int64 = 0,
            downloadedBytes: Int64 = 0,
            totalBytes: Int64 = 0,
            statusLabel: String = "Connecting...",
            connectedPeers: Int = 0,
            isPaused: Bool = false
        ) {
            self.progress = progress
            self.downloadSpeed = downloadSpeed
            self.uploadSpeed = uploadSpeed
            self.downloadedBytes = downloadedBytes
            self.totalBytes = totalBytes
            self.statusLabel = statusLabel
            self.connectedPeers = connectedPeers
            self.isPaused = isPaused
        }

        // MARK: - Computed helpers
        public var formattedDownloadSpeed: String {
            ByteCountFormatter.string(fromByteCount: downloadSpeed, countStyle: .binary) + "/s"
        }

        public var formattedUploadSpeed: String {
            ByteCountFormatter.string(fromByteCount: uploadSpeed, countStyle: .binary) + "/s"
        }

        public var formattedProgress: String {
            String(format: "%.1f%%", progress * 100)
        }

        public var eta: String {
            guard downloadSpeed > 0 else { return "∞" }
            let remaining = totalBytes - downloadedBytes
            guard remaining > 0 else { return "Done" }
            let seconds = Int(Double(remaining) / Double(downloadSpeed))
            if seconds < 60 { return "\(seconds)s" }
            if seconds < 3600 { return "\(seconds / 60)m" }
            return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
        }
    }
}
