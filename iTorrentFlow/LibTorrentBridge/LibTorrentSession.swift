import Foundation

// MARK: - Swift wrapper around the LibTorrent C bridge
/// Replaces the custom pure-Swift engine with a LibTorrent-backed engine
@MainActor
public final class LibTorrentSession: ObservableObject, Identifiable {
    public let id = UUID()
    private let ref: LTSessionRef

    @Published public private(set) var status: TorrentStatus = .stopped
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var downloadSpeed: Int64 = 0
    @Published public private(set) var uploadSpeed: Int64 = 0
    @Published public private(set) var connectedPeers: Int = 0
    @Published public private(set) var totalPeers: Int = 0

    public private(set) var infoHashHex: String = ""
    public var metadata: TorrentMetadata?

    public init(torrentData: Data, savePath: String, trackers: [String] = []) {
        self.ref = lt_session_create()
        configureSession()

        // Convert trackers to C strings
        var cTrackers = trackers.map { UnsafePointer<Int8>(strdup($0)) }
        let result = lt_session_add_torrent(ref,
                                            (torrentData as NSData).bytes.bindMemory(to: Int8.self, capacity: torrentData.count),
                                            Int32(torrentData.count),
                                            savePath,
                                            &cTrackers,
                                            Int32(trackers.count))

        if let cStr = result {
            infoHashHex = String(cString: cStr)
            free(UnsafeMutablePointer(mutating: result))
        }
        cTrackers.forEach { free(UnsafeMutablePointer(mutating: $0)) }

        setupCallbacks()
        status = .downloading
    }

    public init(magnetURI: String, savePath: String) {
        self.ref = lt_session_create()
        configureSession()

        let result = lt_session_add_magnet(ref, magnetURI, savePath)
        if let cStr = result {
            infoHashHex = String(cString: cStr)
            free(UnsafeMutablePointer(mutating: result))
        }

        setupCallbacks()
        status = .fetchingMetadata
    }

    deinit {
        lt_session_destroy(ref)
    }

    private func configureSession() {
        let settings = SettingsManager.shared
        lt_session_set_listen_port(ref, Int32(settings.listenPort))
        lt_session_set_max_connections(ref, Int32(settings.maxConnections))
        lt_session_set_max_upload_rate(ref, Int64(settings.maxUploadSpeed) * 1024)
        lt_session_set_max_download_rate(ref, Int64(settings.maxDownloadSpeed) * 1024)
        lt_session_enable_dht(ref, settings.enableDHT)
        lt_session_enable_lsd(ref, settings.enableLSD)
        lt_session_set_callbacks(ref, nil, nil, nil)
    }

    private func setupCallbacks() {
        let ref = self.ref
        let infoHash = self.infoHashHex

        lt_session_set_callbacks(ref,
            { ih, prog, dlRate, ulRate, peers, seeds, state, stateStr in
                DispatchQueue.main.async {
                    guard let session = TorrentEngine.shared.ltSessions.first(where: { $0.infoHashHex == String(cString: ih!) }) else { return }
                    session.progress = prog
                    session.downloadSpeed = dlRate
                    session.uploadSpeed = ulRate
                    session.connectedPeers = Int(peers)
                    session.totalPeers = Int(seeds)
                    session.status = prog >= 1.0 ? .completed : .downloading
                }
            },
            { ih, pieceIdx in
                // Piece completed notification
            },
            { msg in
                if let m = msg {
                    print("[LibTorrent] \(String(cString: m))")
                }
            }
        )
    }

    // MARK: - Control
    public func pause() {
        lt_session_pause(ref, infoHashHex)
        status = .paused
    }

    public func resume() {
        lt_session_resume(ref, infoHashHex)
        status = .downloading
    }

    public func remove(deleteFiles: Bool = false) {
        lt_session_remove(ref, infoHashHex, deleteFiles)
        status = .stopped
    }

    // MARK: - File Priority
    public func setFilePriority(fileIndex: Int, priority: FilePriority) {
        lt_session_set_file_priority(ref, infoHashHex, Int32(fileIndex), priority.rawValue)
    }

    // MARK: - Trackers
    public func addTracker(_ url: String) {
        lt_session_add_tracker(ref, infoHashHex, url)
    }

    public func replaceTrackers(_ urls: [String]) {
        var cTrackers = urls.map { UnsafePointer<Int8>(strdup($0)) }
        lt_session_replace_trackers(ref, infoHashHex, &cTrackers, Int32(urls.count))
        cTrackers.forEach { free(UnsafeMutablePointer(mutating: $0)) }
    }
}

// MARK: - Backward-compatible wrapper for TorrentSession
@MainActor
public final class LibTorrentEngine: ObservableObject {
    public static let shared = LibTorrentEngine()
    @Published public private(set) var sessions: [LibTorrentSession] = []

    private init() {}

    public func addTorrent(data: Data, savePath: String, trackers: [String] = []) -> LibTorrentSession {
        let session = LibTorrentSession(torrentData: data, savePath: savePath, trackers: trackers)
        sessions.append(session)
        return session
    }

    public func addMagnet(uri: String, savePath: String) -> LibTorrentSession {
        let session = LibTorrentSession(magnetURI: uri, savePath: savePath)
        sessions.append(session)
        return session
    }

    public func pauseAll() {
        sessions.forEach { $0.pause() }
    }

    public func resumeAll() {
        sessions.forEach { $0.resume() }
    }

    public func remove(session: LibTorrentSession, deleteFiles: Bool = false) {
        session.remove(deleteFiles: deleteFiles)
        sessions.removeAll { $0.id == session.id }
    }
}
