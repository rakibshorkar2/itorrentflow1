import Foundation
import BackgroundTasks
import Combine

// MARK: - Torrent Engine
/// Central singleton managing all active torrent sessions
@MainActor
public final class TorrentEngine: ObservableObject {
    public static let shared = TorrentEngine()

    @Published public private(set) var sessions: [TorrentSession] = []

    private let downloadDirectory: URL
    private var store: TorrentStore

    // Background task identifiers
    static let processingTaskID = "com.itorrentflow.app.torrent-processing"
    static let refreshTaskID = "com.itorrentflow.app.torrent-refresh"

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.downloadDirectory = docs.appendingPathComponent("Downloads")
        self.store = TorrentStore()

        try? FileManager.default.createDirectory(
            at: downloadDirectory,
            withIntermediateDirectories: true
        )

        loadPersistedTorrents()
    }

    // MARK: - Add from .torrent file
    public func addTorrent(from fileURL: URL) throws -> TorrentSession {
        let data = try Data(contentsOf: fileURL)
        return try addTorrent(data: data)
    }

    public func addTorrent(data: Data) throws -> TorrentSession {
        let metadata = try TorrentMetadata.parse(from: data)
        return try createSession(metadata: metadata)
    }

    // MARK: - Add from magnet link
    public func addTorrent(magnetURL: String) throws -> TorrentSession {
        let magnet = try MagnetLink.parse(from: magnetURL)
        // Create minimal metadata for magnet (we'll fetch full metadata from peers)
        let metadata = TorrentMetadata.fromMagnet(magnet)
        return try createSession(metadata: metadata)
    }

    // MARK: - Create Session
    private func createSession(metadata: TorrentMetadata) throws -> TorrentSession {
        // Prevent duplicates
        if let existing = sessions.first(where: { $0.metadata.infoHashHex == metadata.infoHashHex }) {
            return existing
        }

        let session = TorrentSession(
            metadata: metadata,
            downloadDirectory: downloadDirectory
        )

        sessions.append(session)
        store.save(session: session)
        return session
    }

    // MARK: - Remove torrent
    public func remove(session: TorrentSession, deleteFiles: Bool = false) {
        session.stop()
        sessions.removeAll { $0.id == session.id }
        store.delete(id: session.id)

        if deleteFiles {
            let fileURL = downloadDirectory.appendingPathComponent(session.metadata.name)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Pause All / Resume All
    public func pauseAll() {
        sessions.forEach { $0.pause() }
    }

    public func resumeAll() {
        sessions.filter { $0.status == .paused }.forEach { $0.start() }
    }

    // MARK: - Background Task Registration
    public func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingTaskID,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundProcessing(task: task as! BGProcessingTask)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskID,
            using: nil
        ) { task in
            Task { @MainActor in
                await self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
            }
        }
    }

    public func scheduleBackgroundTasks() {
        let processingRequest = BGProcessingTaskRequest(identifier: Self.processingTaskID)
        processingRequest.requiresNetworkConnectivity = true
        processingRequest.requiresExternalPower = false
        processingRequest.earliestBeginDate = Date(timeIntervalSinceNow: 60)

        let refreshRequest = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        refreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)

        try? BGTaskScheduler.shared.submit(processingRequest)
        try? BGTaskScheduler.shared.submit(refreshRequest)
    }

    private func handleBackgroundProcessing(task: BGProcessingTask) async {
        scheduleBackgroundTasks()

        // Resume paused sessions
        let activeSessions = sessions.filter { $0.status == .paused || $0.status == .stopped }
        for session in activeSessions { session.start() }

        task.expirationHandler = {
            Task { @MainActor in
                self.sessions.forEach { $0.pause() }
            }
        }

        // Wait for all active downloads
        try? await Task.sleep(nanoseconds: 25 * 60 * 1_000_000_000) // 25 minutes max
        task.setTaskCompleted(success: true)
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        scheduleBackgroundTasks()
        // Update tracker announces
        for session in sessions where session.status == .downloading {
            // Sessions self-manage their tracker connections
        }
        task.setTaskCompleted(success: true)
    }

    // MARK: - Persistence
    private func loadPersistedTorrents() {
        let saved = store.loadAll()
        sessions = saved
    }

    // MARK: - Stats
    public var totalDownloadSpeed: Int64 {
        sessions.reduce(0) { $0 + $1.downloadSpeed }
    }

    public var totalUploadSpeed: Int64 {
        sessions.reduce(0) { $0 + $1.uploadSpeed }
    }

    public var activeTorrents: Int {
        sessions.filter { $0.status == .downloading }.count
    }
}

// MARK: - TorrentMetadata Magnet extension
public extension TorrentMetadata {
    /// Minimal metadata created from a magnet link (no pieces until metadata fetched from peers)
    static func fromMagnet(_ magnet: MagnetLink) -> TorrentMetadata {
        TorrentMetadata(
            infoHash: magnet.infoHashData ?? Data(repeating: 0, count: 20),
            name: magnet.displayName ?? magnet.infoHash,
            totalSize: magnet.exactLength ?? 0,
            pieceLength: 0,
            pieces: [],
            files: [],
            trackerURLs: magnet.trackers,
            isPrivate: false,
            comment: nil,
            createdBy: nil,
            creationDate: nil
        )
    }
}
