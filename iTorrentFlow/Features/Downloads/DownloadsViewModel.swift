import SwiftUI
import Combine

// MARK: - Downloads ViewModel
@MainActor
public final class DownloadsViewModel: ObservableObject {
    @Published public var sessions: [TorrentSession] = []
    @Published public var selectedFilter: TorrentStatus? = nil
    @Published public var sortOrder: SortOrder = .dateAdded
    @Published public var searchText: String = ""
    @Published public var showAddSheet: Bool = false
    @Published public var showDocumentPicker: Bool = false
    @Published public var totalDownloadSpeed: Int64 = 0
    @Published public var totalUploadSpeed: Int64 = 0

    private let engine = TorrentEngine.shared
    private var cancellables = Set<AnyCancellable>()
    private var speedTimer: Timer?

    public init() {
        engine.$sessions
            .receive(on: RunLoop.main)
            .assign(to: &$sessions)

        startSpeedMonitor()
    }

    // MARK: - Filtered & Sorted Sessions
    public var filteredSessions: [TorrentSession] {
        var result = sessions

        if !searchText.isEmpty {
            result = result.filter {
                $0.metadata.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let filter = selectedFilter {
            result = result.filter { $0.status == filter }
        }

        switch sortOrder {
        case .dateAdded:
            break // Keep insertion order
        case .name:
            result.sort { $0.metadata.name < $1.metadata.name }
        case .progress:
            result.sort { $0.progress > $1.progress }
        case .size:
            result.sort { $0.metadata.totalSize > $1.metadata.totalSize }
        case .status:
            result.sort { $0.status.label < $1.status.label }
        }

        return result
    }

    public var filterOptions: [(String, TorrentStatus?)] {
        [
            ("All", nil),
            ("Active", .downloading),
            ("Paused", .paused),
            ("Completed", .completed),
            ("Stopped", .stopped)
        ]
    }

    // MARK: - Actions
    public func remove(session: TorrentSession, deleteFiles: Bool = false) {
        engine.remove(session: session, deleteFiles: deleteFiles)
    }

    public func pauseAll() { engine.pauseAll() }
    public func resumeAll() { engine.resumeAll() }

    // MARK: - Speed Monitor
    private func startSpeedMonitor() {
        speedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.totalDownloadSpeed = self?.engine.totalDownloadSpeed ?? 0
                self?.totalUploadSpeed = self?.engine.totalUploadSpeed ?? 0
            }
        }
    }

    // MARK: - Sort Order
    public enum SortOrder: String, CaseIterable {
        case dateAdded = "Date Added"
        case name = "Name"
        case progress = "Progress"
        case size = "Size"
        case status = "Status"
    }
}
