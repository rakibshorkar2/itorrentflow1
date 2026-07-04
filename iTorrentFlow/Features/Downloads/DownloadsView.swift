import SwiftUI

// MARK: - Downloads View
public struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var selectedSession: TorrentSession? = nil
    @State private var showDetail: Bool = false
    @State private var headerOffset: CGFloat = 0

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Theme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stats Header
                    statsHeader
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.top, Theme.spacing8)

                    // Filter Chips
                    filterChips
                        .padding(.top, Theme.spacing12)

                    // Search Bar
                    searchBar
                        .padding(.horizontal, Theme.spacing16)
                        .padding(.top, Theme.spacing8)

                    // Torrent List
                    if viewModel.filteredSessions.isEmpty {
                        emptyState
                    } else {
                        torrentList
                    }
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sortMenu
                    addButton
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    bulkActionsMenu
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                AddTorrentView()
            }
            .sheet(item: $selectedSession) { session in
                DownloadDetailView(session: session)
            }
            .fileImporter(
                isPresented: $viewModel.showDocumentPicker,
                allowedContentTypes: [.init(filenameExtension: "torrent")!],
                allowsMultipleSelection: true
            ) { result in
                handleTorrentImport(result: result)
            }
        }
    }

    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: Theme.spacing12) {
            StatCard(
                label: "Downloading",
                value: "\(TorrentEngine.shared.activeTorrents)",
                icon: "arrow.down.circle.fill",
                color: Theme.downloadColor
            )
            StatCard(
                label: "↓ Speed",
                value: formatSpeed(viewModel.totalDownloadSpeed),
                icon: "arrow.down",
                color: Theme.downloadColor
            )
            StatCard(
                label: "↑ Speed",
                value: formatSpeed(viewModel.totalUploadSpeed),
                icon: "arrow.up",
                color: Theme.uploadColor
            )
        }
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing8) {
                ForEach(viewModel.filterOptions, id: \.0) { label, status in
                    FilterChip(
                        label: label,
                        isSelected: viewModel.selectedFilter == status
                    ) {
                        withAnimation(Theme.snappy) {
                            viewModel.selectedFilter = viewModel.selectedFilter == status ? nil : status
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.spacing16)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: Theme.spacing8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textTertiary)
            TextField("Search torrents...", text: $viewModel.searchText)
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(Theme.spacing12)
        .glassMorphism(cornerRadius: Theme.radiusMedium)
    }

    // MARK: - Torrent List
    private var torrentList: some View {
        ScrollView {
            LazyVStack(spacing: Theme.spacing8) {
                ForEach(viewModel.filteredSessions) { session in
                    DownloadRowView(session: session) {
                        selectedSession = session
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, Theme.spacing16)
            .padding(.top, Theme.spacing12)
            .padding(.bottom, 100) // Tab bar clearance
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: Theme.spacing20) {
            Spacer()
            Image(systemName: "arrow.down.to.line.circle")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.accent.opacity(0.7), Theme.accentSecondary.opacity(0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            VStack(spacing: Theme.spacing8) {
                Text("No Downloads")
                    .font(Theme.titleFont(size: 22))
                    .foregroundStyle(Theme.textPrimary)
                Text(viewModel.searchText.isEmpty
                     ? "Add a magnet link or .torrent file to get started"
                     : "No results matching '\(viewModel.searchText)'")
                    .font(Theme.bodyFont())
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if viewModel.searchText.isEmpty {
                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Label("Add Torrent", systemImage: "plus.circle.fill")
                        .font(Theme.headlineFont())
                        .foregroundStyle(.black)
                        .padding(.horizontal, Theme.spacing24)
                        .padding(.vertical, Theme.spacing12)
                        .background(Theme.accentGradient)
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(Theme.spacing24)
    }

    // MARK: - Toolbar
    private var addButton: some View {
        Menu {
            Button {
                viewModel.showAddSheet = true
            } label: {
                Label("Magnet Link", systemImage: "link")
            }
            Button {
                viewModel.showDocumentPicker = true
            } label: {
                Label("Torrent File", systemImage: "doc.badge.plus")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Theme.accent)
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(DownloadsViewModel.SortOrder.allCases, id: \.self) { order in
                Button {
                    withAnimation(Theme.snappy) { viewModel.sortOrder = order }
                } label: {
                    Label(
                        order.rawValue,
                        systemImage: viewModel.sortOrder == order ? "checkmark" : ""
                    )
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.system(size: 20))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var bulkActionsMenu: some View {
        Menu {
            Button { viewModel.resumeAll() } label: {
                Label("Resume All", systemImage: "play.fill")
            }
            Button { viewModel.pauseAll() } label: {
                Label("Pause All", systemImage: "pause.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Helpers
    private func formatSpeed(_ bps: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bps, countStyle: .binary) + "/s"
    }

    private func handleTorrentImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let session = try TorrentEngine.shared.addTorrent(from: url)
                    if SettingsManager.shared.startOnAdd { session.start() }
                } catch {
                    print("Failed to add torrent: \(error)")
                }
            }
        case .failure(let error):
            print("Document picker error: \(error)")
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)
                Text(label)
                    .font(Theme.captionFont(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(value)
                .font(Theme.headlineFont(size: 16))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacing12)
        .glassMorphism(cornerRadius: Theme.radiusMedium)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.captionFont(size: 12))
                .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, Theme.spacing12)
                .padding(.vertical, Theme.spacing6)
                .background(
                    isSelected
                        ? AnyShapeStyle(Theme.accentGradient)
                        : AnyShapeStyle(Theme.surface.opacity(0.8))
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Theme.glassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Fix for spacing
private extension Theme {
    static let spacing6: CGFloat = 6
}
