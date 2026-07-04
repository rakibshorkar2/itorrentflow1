import SwiftUI

public struct DownloadsView: View {
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var selectedSession: TorrentSession? = nil
    @State private var showAddSheet = false

    public var body: some View {
        NavigationStack {
            List {
                statsSection

                if viewModel.filteredSessions.isEmpty {
                    emptySection
                } else {
                    torrentsSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search torrents")
            .refreshable {
                // Refresh tracker announces
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sortMenu
                    addMenu
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    bulkActionsMenu
                }
            }
            .sheet(item: $selectedSession) { session in
                DownloadDetailView(session: session)
            }
            .sheet(isPresented: $showAddSheet) {
                AddTorrentView()
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

    // MARK: - Stats Section
    private var statsSection: some View {
        Section {
            HStack {
                StatItem(
                    label: "Active",
                    value: "\(TorrentEngine.shared.activeTorrents)",
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )
                Divider()
                StatItem(
                    label: "Download",
                    value: formatSpeed(viewModel.totalDownloadSpeed),
                    icon: "arrow.down",
                    color: .blue
                )
                Divider()
                StatItem(
                    label: "Upload",
                    value: formatSpeed(viewModel.totalUploadSpeed),
                    icon: "arrow.up",
                    color: .green
                )
            }
            .frame(maxWidth: .infinity)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Torrents Section
    private var torrentsSection: some View {
        Section {
            ForEach(viewModel.filteredSessions) { session in
                DownloadRowView(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSession = session
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            TorrentEngine.shared.remove(session: session, deleteFiles: false)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        if session.status.isActive {
                            Button {
                                session.pause()
                            } label: {
                                Label("Pause", systemImage: "pause.fill")
                            }
                            .tint(.orange)
                        } else {
                            Button {
                                session.start()
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .tint(.green)
                        }
                    }
                    .contextMenu {
                        TorrentContextMenu(session: session)
                    }
            }
        } header: {
            filterSection
        }
    }

    // MARK: - Filter
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.filterOptions, id: \.0) { label, status in
                    Button {
                        withAnimation(Theme.snappy) {
                            viewModel.selectedFilter = viewModel.selectedFilter == status ? nil : status
                        }
                    } label: {
                        Text(label)
                            .font(.subheadline)
                            .foregroundStyle(viewModel.selectedFilter == status ? Color.white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedFilter == status ? Theme.accent : Color(.quaternarySystemFill))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .textCase(nil)
    }

    // MARK: - Empty State
    private var emptySection: some View {
        Section {
            VStack(spacing: 16) {
                Spacer().frame(height: 40)
                Image(systemName: "arrow.down.to.line.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text(viewModel.searchText.isEmpty ? "No Downloads" : "No Results")
                    .font(.title3.weight(.semibold))
                Text(viewModel.searchText.isEmpty
                     ? "Add a magnet link or .torrent file to get started"
                     : "No torrents matching '\(viewModel.searchText)'")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if viewModel.searchText.isEmpty {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Torrent", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer().frame(height: 40)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Toolbar Menus
    private var addMenu: some View {
        Menu {
            Button {
                showAddSheet = true
            } label: {
                Label("Magnet Link", systemImage: "link")
            }
            Button {
                viewModel.showDocumentPicker = true
            } label: {
                Label("Torrent File", systemImage: "doc.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(DownloadsViewModel.SortOrder.allCases, id: \.self) { order in
                Button {
                    withAnimation(Theme.snappy) { viewModel.sortOrder = order }
                } label: {
                    Label(order.rawValue, systemImage: viewModel.sortOrder == order ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
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
        }
    }

    private func formatSpeed(_ bps: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bps, countStyle: .binary) + "/s"
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

// MARK: - Stat Item
struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
