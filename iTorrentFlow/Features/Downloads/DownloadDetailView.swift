import SwiftUI

public struct DownloadDetailView: View {
    @ObservedObject var session: TorrentSession
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .overview
    @State private var showAddTracker = false
    @State private var newTrackerURL = ""

    enum DetailTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case files = "Files"
        case peers = "Peers"
        case trackers = "Trackers"
        case pieces = "Pieces"
        var id: Self { self }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    ForEach(DetailTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List {
                    switch selectedTab {
                    case .overview: overviewSection
                    case .files: filesSection
                    case .peers: peersSection
                    case .trackers: trackersSection
                    case .pieces: piecesSection
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(session.metadata.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    controlButton
                }
            }
            .alert("Add Tracker", isPresented: $showAddTracker) {
                TextField("Tracker URL", text: $newTrackerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) { newTrackerURL = "" }
                Button("Add") {
                    addTracker(newTrackerURL)
                    newTrackerURL = ""
                }
            } message: {
                Text("Enter the full announce URL")
            }
        }
    }

    // MARK: - Overview
    private var overviewSection: some View {
        Section("Info") {
            InfoRow(label: "Name", value: session.metadata.name)
            InfoRow(label: "Size", value: ByteCountFormatter.string(fromByteCount: session.metadata.totalSize, countStyle: .file))
            InfoRow(label: "Downloaded", value: ByteCountFormatter.string(
                fromByteCount: Int64(session.progress * Double(session.metadata.totalSize)), countStyle: .file))
            InfoRow(label: "Info Hash", value: session.metadata.infoHashHex, isMonospace: true)
            InfoRow(label: "Pieces", value: "\(session.metadata.pieces.count) × \(ByteCountFormatter.string(fromByteCount: Int64(session.metadata.pieceLength), countStyle: .memory))")
            InfoRow(label: "Files", value: "\(session.metadata.files.count)")
            InfoRow(label: "Connected Peers", value: "\(session.connectedPeers)")
            if let comment = session.metadata.comment {
                InfoRow(label: "Comment", value: comment)
            }
            if let date = session.metadata.creationDate {
                InfoRow(label: "Created", value: date.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    // MARK: - Files
    private var filesSection: some View {
        Section {
            ForEach(session.metadata.files) { file in
                FilePriorityRow(
                    file: file,
                    priority: file.priority,
                    onChange: { priority in
                        Task { await session.setFilePriority(fileID: file.id, priority: priority) }
                    }
                )
            }
        } header: {
            if session.metadata.files.contains(where: { $0.priority == .skip }) {
                Text("File Priority — Skipping some files")
            } else {
                Text("File Priority")
            }
        }
    }

    // MARK: - Peers
    private var peersSection: some View {
        Section {
            if session.connectedPeers == 0 {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No peers connected")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .listRowBackground(Color(.systemGroupedBackground))
            } else {
                ForEach(0..<min(session.connectedPeers, 20), id: \.self) { i in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text("Peer \(i + 1)")
                            .font(.subheadline)
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        } header: {
            Text("Connected Peers")
        }
    }

    // MARK: - Trackers
    private var trackersSection: some View {
        Section {
            ForEach(session.metadata.trackerURLs, id: \.self) { tracker in
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text(tracker)
                        .font(.subheadline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Circle()
                        .fill(session.status.isActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        removeTracker(tracker)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        } header: {
            HStack {
                Text("Trackers (\(session.metadata.trackerURLs.count))")
                Spacer()
                Button {
                    showAddTracker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
    }

    // MARK: - Pieces
    private var piecesSection: some View {
        Section {
            PieceVisualizerView(pieces: session.pieceStatuses, height: 24)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            HStack(spacing: 16) {
                Legend(color: Theme.accent, label: "Downloaded")
                Legend(color: Theme.warningColor, label: "Downloading")
                Legend(color: Color(.separator).opacity(0.3), label: "Missing")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("\(session.pieceStatuses.filter { $0 == .verified }.count) / \(session.pieceStatuses.count) pieces")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } header: {
            Text("Piece Map")
        }
    }

    // MARK: - Control
    private var controlButton: some View {
        Button {
            withAnimation(Theme.snappy) {
                if session.status.isActive {
                    session.pause()
                } else {
                    session.start()
                }
            }
        } label: {
            Image(systemName: session.status.isActive ? "pause.circle.fill" : "play.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(session.status.isActive ? Theme.warningColor : Theme.accent)
        }
    }

    private func addTracker(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        session.metadata.trackerURLs.append(trimmed)
    }

    private func removeTracker(_ url: String) {
        session.metadata.trackerURLs.removeAll { $0 == url }
    }
}

struct Legend: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
        }
    }
}
