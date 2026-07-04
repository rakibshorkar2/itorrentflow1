import Foundation

// MARK: - Torrent Store (SwiftData-compatible persistence)
/// Persists torrent list to UserDefaults + file system for iOS 16 compatibility
public final class TorrentStore {
    private let key = "iTorrentFlow.savedTorrents"
    private let defaults = UserDefaults(suiteName: "group.com.itorrentflow.app") ?? .standard

    public init() {}

    // MARK: - Save
    public func save(session: TorrentSession) {
        var items = loadAllItems()
        let item = makeItem(from: session)
        if let idx = items.firstIndex(where: { $0.id == session.id }) {
            items[idx] = item
        } else {
            items.append(item)
        }
        persist(items)
    }

    // MARK: - Update
    public func update(id: UUID, transform: (inout TorrentItem) -> Void) {
        var items = loadAllItems()
        if let idx = items.firstIndex(where: { $0.id == id }) {
            transform(&items[idx])
            persist(items)
        }
    }

    // MARK: - Delete
    public func delete(id: UUID) {
        var items = loadAllItems()
        items.removeAll { $0.id == id }
        persist(items)
    }

    // MARK: - Load
    public func loadAll() -> [TorrentSession] {
        // Return empty sessions (actual session creation happens in TorrentEngine)
        return []
    }

    public func loadAllItems() -> [TorrentItem] {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([TorrentItem].self, from: data) else {
            return []
        }
        return items
    }

    // MARK: - Helpers
    private func makeItem(from session: TorrentSession) -> TorrentItem {
        TorrentItem(
            id: session.id,
            name: session.metadata.name,
            infoHashHex: session.metadata.infoHashHex,
            totalSize: session.metadata.totalSize,
            downloadedSize: Int64(session.progress * Double(session.metadata.totalSize)),
            progress: session.progress,
            status: itemStatus(from: session.status),
            trackers: session.metadata.trackerURLs,
            fileCount: session.metadata.files.count
        )
    }

    private func itemStatus(from status: TorrentStatus) -> TorrentItemStatus {
        switch status {
        case .stopped: return .stopped
        case .connecting, .fetchingMetadata: return .connecting
        case .downloading: return .downloading
        case .seeding: return .seeding
        case .paused: return .paused
        case .completed: return .completed
        case .error: return .error
        }
    }

    private func persist(_ items: [TorrentItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}
