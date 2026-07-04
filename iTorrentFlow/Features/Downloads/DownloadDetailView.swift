import SwiftUI
import MapKit

// MARK: - Download Detail View
public struct DownloadDetailView: View {
    @ObservedObject var session: TorrentSession
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .overview
    @State private var showAddTracker = false
    @State private var newTrackerURL = ""

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case files = "Files"
        case peers = "Peers"
        case trackers = "Trackers"
        case pieces = "Pieces"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.spacing16) {
                        // Hero Section
                        heroSection

                        // Tab Picker
                        tabPicker

                        // Content
                        switch selectedTab {
                        case .overview: overviewSection
                        case .files: filesSection
                        case .peers: peersSection
                        case .trackers: trackersSection
                        case .pieces: piecesSection
                        }
                    }
                    .padding(.horizontal, Theme.spacing16)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(session.metadata.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    controlButton
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: Theme.spacing16) {
            // Big Progress Ring
            ZStack {
                CircularProgressView(
                    progress: session.progress,
                    size: 120,
                    lineWidth: 10,
                    showLabel: true,
                    gradient: session.status.isActive
                        ? [Theme.accent, Theme.accentSecondary]
                        : [Theme.textSecondary, Theme.textTertiary]
                )
                .padding(4)
                .background(
                    Circle()
                        .fill(Theme.surfaceElevated)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 20, x: 0, y: 0)
                )
            }

            // Status + Control
            StatusPill(status: session.status)

            // Speed Graph
            if session.status.isActive {
                SpeedGraphView(
                    downloadSpeed: session.downloadSpeed,
                    uploadSpeed: session.uploadSpeed
                )
                .cardStyle()
            }
        }
        .padding(.top, Theme.spacing8)
    }

    // MARK: - Tab Picker
    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.spacing8) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(Theme.snappy) { selectedTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(Theme.captionFont(size: 13))
                            .foregroundStyle(selectedTab == tab ? .black : Theme.textSecondary)
                            .padding(.horizontal, Theme.spacing12)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == tab
                                    ? AnyShapeStyle(Theme.accentGradient)
                                    : AnyShapeStyle(Theme.surface.opacity(0.8))
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Overview
    private var overviewSection: some View {
        VStack(spacing: Theme.spacing12) {
            InfoRow(label: "Name", value: session.metadata.name)
            InfoRow(label: "Total Size", value: ByteCountFormatter.string(fromByteCount: session.metadata.totalSize, countStyle: .file))
            InfoRow(label: "Downloaded", value: ByteCountFormatter.string(fromByteCount: Int64(session.progress * Double(session.metadata.totalSize)), countStyle: .file))
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
        .cardStyle()
    }

    // MARK: - Files
    private var filesSection: some View {
        VStack(spacing: Theme.spacing8) {
            HStack {
                Text("File Priority")
                    .font(Theme.captionFont())
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                if session.metadata.files.contains(where: { $0.priority == .skip }) {
                    Text("Skipping files")
                        .font(Theme.captionFont(size: 10))
                        .foregroundStyle(Theme.warningColor)
                }
            }

            FileListView(
                files: session.metadata.files,
                filePriorityMap: [:],
                onPriorityChange: { fileID, priority in
                    Task {
                        await session.setFilePriority(fileID: fileID, priority: priority)
                    }
                }
            )
        }
    }

    // MARK: - Peers
    private var peersSection: some View {
        VStack(spacing: Theme.spacing8) {
            if session.connectedPeers == 0 {
                Text("No peers connected")
                    .font(Theme.bodyFont())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.spacing24)
            } else {
                ForEach(0..<min(session.connectedPeers, 20), id: \.self) { i in
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Theme.accentSecondary)
                        Text("Peer \(i + 1)")
                            .font(Theme.bodyFont(size: 13))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("Connected")
                            .font(Theme.captionFont(size: 11))
                            .foregroundStyle(Theme.accentTertiary)
                    }
                    .padding(Theme.spacing12)
                    .glassMorphism(cornerRadius: Theme.radiusMedium)
                }
            }
        }
    }

    // MARK: - Trackers
    private var trackersSection: some View {
        VStack(spacing: Theme.spacing8) {
            HStack {
                Text("Trackers (\(session.metadata.trackerURLs.count))")
                    .font(Theme.captionFont())
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button {
                    showAddTracker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.system(size: 18))
                }
            }

            ForEach(session.metadata.trackerURLs, id: \.self) { tracker in
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    Text(tracker)
                        .font(Theme.captionFont(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Circle()
                        .fill(session.status.isActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                }
                .padding(Theme.spacing12)
                .glassMorphism(cornerRadius: Theme.radiusMedium)
                .contextMenu {
                    Button(role: .destructive) {
                        removeTracker(tracker)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
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
            Text("Enter the full announce URL (e.g. udp://tracker.example.com:80/announce)")
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

    // MARK: - Pieces
    private var piecesSection: some View {
        VStack(spacing: Theme.spacing12) {
            HStack {
                Legend(color: Theme.accent, label: "Downloaded")
                Legend(color: Theme.warningColor, label: "Downloading")
                Legend(color: Theme.surface, label: "Missing")
            }

            PieceVisualizerView(pieces: session.pieceStatuses, height: 20)

            Text("\(session.pieceStatuses.filter { $0 == .verified }.count) / \(session.pieceStatuses.count) pieces")
                .font(Theme.captionFont())
                .foregroundStyle(Theme.textSecondary)
        }
        .cardStyle()
    }

    // MARK: - Control Button
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
                .font(.system(size: 26))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(session.status.isActive ? Theme.warningColor : Theme.accent)
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mkv", "avi", "mov": return "film.fill"
        case "mp3", "flac", "m4a", "aac": return "music.note"
        case "jpg", "jpeg", "png", "gif", "webp": return "photo.fill"
        case "pdf": return "doc.richtext.fill"
        case "zip", "rar", "7z", "tar", "gz": return "archivebox.fill"
        case "dmg", "exe", "pkg": return "app.badge.checkmark.fill"
        case "epub", "mobi": return "book.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    var isMonospace: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(Theme.captionFont())
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(isMonospace ? Theme.monoFont(size: 12) : Theme.bodyFont(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        Divider().background(Theme.divider)
    }
}

// MARK: - Legend
struct Legend: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
                .font(Theme.captionFont(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}
