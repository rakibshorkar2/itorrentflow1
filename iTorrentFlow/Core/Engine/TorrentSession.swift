import Foundation
import Combine
import ActivityKit
import BackgroundTasks

// MARK: - Torrent Session
/// Manages a single torrent download — connects to peers, downloads pieces
@MainActor
public final class TorrentSession: ObservableObject, Identifiable {
    public let id: UUID
    public var metadata: TorrentMetadata

    @Published public private(set) var status: TorrentStatus = .stopped
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var downloadSpeed: Int64 = 0
    @Published public private(set) var uploadSpeed: Int64 = 0
    @Published public private(set) var connectedPeers: Int = 0
    @Published public private(set) var pieceStatuses: [PieceStatus] = []

    public var downloadDirectory: URL
    private var pieceManager: PieceManager?
    private var trackerClient = TrackerClient()
    private var peerConnections: [PeerConnection] = []
    private var downloadTask: Task<Void, Never>?
    private var speedTimer: Timer?
    private var speedBytesLast: Int64 = 0
    private var liveActivity: Any?
    private var localPeerID: Data

    // Settings
    public var maxUploadSpeed: Int64 = 0   // 0 = unlimited
    public var maxDownloadSpeed: Int64 = 0 // 0 = unlimited
    public var isSequential: Bool = false

    public init(id: UUID = UUID(), metadata: TorrentMetadata, downloadDirectory: URL) {
        self.id = id
        self.metadata = metadata
        self.downloadDirectory = downloadDirectory
        self.localPeerID = Self.generatePeerID()
        self.pieceStatuses = Array(repeating: .missing, count: metadata.pieces.count)
    }

    // MARK: - Peer ID Generation
    private static func generatePeerID() -> Data {
        // Format: -IT0100-<random 12 bytes>
        var data = Data("-IT0100-".utf8)
        data.append(contentsOf: (0..<12).map { _ in UInt8.random(in: 0...255) })
        return data
    }

    // MARK: - Start / Resume
    public func start() {
        guard status == .stopped || status.isError else { return }
        status = .connecting
        startLiveActivity()

        downloadTask = Task {
            await runDownload()
        }

        startSpeedTimer()
    }

    // MARK: - Pause
    public func pause() {
        downloadTask?.cancel()
        downloadTask = nil
        peerConnections.forEach { conn in
            Task { await conn.disconnect() }
        }
        peerConnections = []
        status = .paused
        stopSpeedTimer()
        updateLiveActivity()
    }

    // MARK: - Stop
    public func stop() {
        pause()
        status = .stopped
        endLiveActivity()
    }

    // MARK: - Core Download Loop
    private func runDownload() async {
        do {
            // For magnet links (no pieces), fetch metadata from peers first
            if metadata.pieces.isEmpty {
                await fetchMetadataFromPeers()
                if metadata.pieces.isEmpty {
                    await MainActor.run { self.status = .error("Failed to fetch metadata from peers") }
                    return
                }
            }

            let pm = try PieceManager(metadata: metadata, downloadDirectory: downloadDirectory)
            self.pieceManager = pm

            // Initial tracker announce
            var allPeers: [(String, UInt16)] = await announceToTrackers(left: metadata.totalSize)
            status = .downloading
            connectedPeers = 0

            // Launch periodic tracker re-announce (every 30 min) alongside downloads
            let reannounceTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                    let freshPeers = await self.announceToTrackers(left: self.metadata.totalSize)
                    allPeers.append(contentsOf: freshPeers)
                }
            }

            // Connect to up to 30 peers and download
            let uniquePeers = uniquePeers(from: allPeers, max: 30)

            await withTaskGroup(of: Void.self) { group in
                for (ip, port) in uniquePeers {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.connectAndDownload(ip: ip, port: port, pm: pm)
                    }
                }
            }

            reannounceTask.cancel()

            let isComplete = await pm.isComplete
            if isComplete {
                await MainActor.run {
                    self.status = .completed
                    self.progress = 1.0
                    self.stopSpeedTimer()
                    self.endLiveActivity()
                }
            } else {
                await MainActor.run { self.status = .stopped }
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    private func announceToTrackers(left: Int64) async -> [(String, UInt16)] {
        var allPeers: [(String, UInt16)] = []
        await withTaskGroup(of: [(String, UInt16)].self) { group in
            for trackerURL in metadata.trackerURLs.prefix(5) {
                group.addTask {
                    do {
                        let response = try await self.trackerClient.announce(
                            trackerURL: trackerURL,
                            infoHash: self.metadata.infoHash,
                            peerID: self.localPeerID,
                            left: left
                        )
                        return response.peers
                    } catch {
                        return []
                    }
                }
            }
            for await peers in group {
                allPeers.append(contentsOf: peers)
            }
        }
        return allPeers
    }

    private func uniquePeers(from allPeers: [(String, UInt16)], max: Int) -> [(String, UInt16)] {
        Array(Set(allPeers.map { "\($0.0):\($0.1)" })
            .compactMap { str -> (String, UInt16)? in
                let parts = str.split(separator: ":"); guard parts.count == 2 else { return nil }
                return (String(parts[0]), UInt16(parts[1]) ?? 6881)
            }.prefix(max))
    }

    private func fetchMetadataFromPeers() async {
        var allPeers: [(String, UInt16)] = []
        await withTaskGroup(of: [(String, UInt16)].self) { group in
            for trackerURL in metadata.trackerURLs.prefix(5) {
                group.addTask {
                    do {
                        let response = try await self.trackerClient.announce(
                            trackerURL: trackerURL,
                            infoHash: self.metadata.infoHash,
                            peerID: self.localPeerID,
                            left: 0
                        )
                        return response.peers
                    } catch {
                        return []
                    }
                }
            }
            for await peers in group {
                allPeers.append(contentsOf: peers)
            }
        }

        let uniquePeers = Array(Set(allPeers.map { "\($0.0):\($0.1)" })
            .compactMap { str -> (String, UInt16)? in
                let parts = str.split(separator: ":"); guard parts.count == 2 else { return nil }
                return (String(parts[0]), UInt16(parts[1]) ?? 6881)
            }.prefix(10))

        for (ip, port) in uniquePeers {
            guard metadata.pieces.isEmpty else { return }
            let conn = PeerConnection(host: ip, port: port, infoHash: metadata.infoHash, localPeerID: localPeerID)
            do {
                try await conn.connect()
                let rawInfoDict = try await conn.fetchMetadata()
                // BEP 9 returns just the bencoded "info" dict — wrap it in a torrent structure
                var torrentData = Data()
                torrentData.append(contentsOf: "d4:info".utf8)
                torrentData.append(rawInfoDict)
                torrentData.append(UInt8(ascii: "e"))
                let parsedMeta = try TorrentMetadata.parse(from: torrentData)
                await MainActor.run {
                    self.metadata = parsedMeta
                }
                await conn.disconnect()
                return
            } catch {
                await conn.disconnect()
                continue
            }
        }
    }

    private func connectAndDownload(ip: String, port: UInt16, pm: PieceManager) async {
        let conn = PeerConnection(
            host: ip,
            port: port,
            infoHash: metadata.infoHash,
            localPeerID: localPeerID
        )
        do {
            try await conn.connect()
            await MainActor.run { [weak self] in
                self?.peerConnections.append(conn)
                self?.connectedPeers += 1
            }
            try await conn.sendInterested()

            // Download pieces from this peer
            while !Task.isCancelled {
                let isPaused = await MainActor.run { [weak self] in self?.status == .paused || self?.status == .stopped }
                if isPaused { break }

                let idx = await pm.nextMissingPieceIndex
                guard let pieceIdx = idx else { break }
                await pm.markPieceRequesting(pieceIdx)

                let pLen = pieceLength(for: pieceIdx)
                let blockSize: UInt32 = 16384
                var begin: UInt32 = 0
                let totalLen = UInt32(pLen)

                while begin < totalLen && !Task.isCancelled {
                    let reqLen = min(blockSize, totalLen - begin)
                    do {
                        let data = try await conn.requestPiece(
                            index: UInt32(pieceIdx),
                            begin: begin,
                            length: reqLen
                        )
                        try await pm.receivePiece(
                            index: pieceIdx,
                            begin: Int(begin),
                            data: data
                        )
                        begin += reqLen
                    } catch PeerError.choked {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch {
                        // Hash mismatch, timeout, or other piece error — retry piece
                        break
                    }
                }

                let p = await pm.progress
                await MainActor.run { [weak self] in
                    self?.progress = p
                    self?.updateLiveActivity()
                }
            }

            await conn.disconnect()
            await MainActor.run { [weak self] in
                self?.connectedPeers = max(0, (self?.connectedPeers ?? 1) - 1)
            }
        } catch {
            await conn.disconnect()
            await MainActor.run { [weak self] in
                self?.connectedPeers = max(0, (self?.connectedPeers ?? 1) - 1)
            }
        }
    }

    private func pieceLength(for index: Int) -> Int {
        if index == metadata.pieces.count - 1 {
            let remainder = Int(metadata.totalSize) % metadata.pieceLength
            return remainder == 0 ? metadata.pieceLength : remainder
        }
        return metadata.pieceLength
    }

    // MARK: - Speed Timer
    private func startSpeedTimer() {
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let pm = self.pieceManager else { return }
                let current = await pm.downloadedBytes
                self.downloadSpeed = current - self.speedBytesLast
                self.speedBytesLast = current
                let p = await pm.progress
                self.progress = p
                let statuses = await pm.pieceStatusArray
                self.pieceStatuses = statuses
                self.updateLiveActivity()
            }
        }
    }

    private func stopSpeedTimer() {
        speedTimer?.invalidate()
        speedTimer = nil
    }

    // MARK: - Live Activity (Dynamic Island)
    private func startLiveActivity() {
        guard SettingsManager.shared.showDynamicIsland else { return }
        if #available(iOS 16.1, *) {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            let attributes = TorrentLiveActivityAttributes(
                torrentName: metadata.name,
                torrentID: id.uuidString
            )
            let state = TorrentLiveActivityAttributes.TorrentDownloadState(
                progress: 0,
                statusLabel: "Starting..."
            )
            do {
                let activity = try Activity<TorrentLiveActivityAttributes>.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
                liveActivity = activity as Any
            } catch {
                print("Live Activity error: \(error)")
            }
        }
    }

    private func updateLiveActivity() {
        if #available(iOS 16.1, *) {
            guard let activity = liveActivity as? Activity<TorrentLiveActivityAttributes> else { return }
            let state = TorrentLiveActivityAttributes.TorrentDownloadState(
                progress: progress,
                downloadSpeed: downloadSpeed,
                uploadSpeed: uploadSpeed,
                downloadedBytes: Int64(progress * Double(metadata.totalSize)),
                totalBytes: metadata.totalSize,
                statusLabel: status.label,
                connectedPeers: connectedPeers,
                isPaused: status == .paused
            )
            Task {
                await activity.update(using: state)
            }
        }
    }

    public func endLiveActivity() {
        if #available(iOS 16.1, *) {
            Task {
                await (liveActivity as? Activity<TorrentLiveActivityAttributes>)?.end(
                    using: TorrentLiveActivityAttributes.TorrentDownloadState(
                        progress: progress,
                        statusLabel: status == .completed ? "Complete" : "Stopped"
                    ),
                    dismissalPolicy: .after(Date.now + 5)
                )
                liveActivity = nil
            }
        }
    }
}


