import SwiftUI

// MARK: - Download Row View
public struct DownloadRowView: View {
    @ObservedObject var session: TorrentSession
    var onTap: () -> Void

    @State private var isPressed = false

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.spacing12) {
                // Circular progress
                CircularProgressView(
                    progress: session.progress,
                    size: 52,
                    lineWidth: 4,
                    showLabel: true,
                    gradient: session.status.isActive
                        ? [Theme.accent, Theme.accentSecondary]
                        : [Theme.textSecondary, Theme.textTertiary]
                )

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.metadata.name)
                        .font(Theme.headlineFont(size: 14))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Progress bar
                    GradientProgressBar(
                        progress: session.progress,
                        height: 3,
                        gradient: session.status.isActive
                            ? [Theme.downloadColor, Theme.accentSecondary]
                            : [Theme.textTertiary, Theme.textSecondary]
                    )

                    HStack(spacing: 8) {
                        // Status
                        StatusPill(status: session.status)

                        // Size
                        if session.metadata.totalSize > 0 {
                            Text(ByteCountFormatter.string(fromByteCount: session.metadata.totalSize, countStyle: .file))
                                .font(Theme.captionFont(size: 10))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Spacer()

                        // Peers
                        if session.status.isActive && session.connectedPeers > 0 {
                            Label("\(session.connectedPeers)", systemImage: "person.2.fill")
                                .font(Theme.captionFont(size: 10))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }

                Spacer()

                // Speed column
                if session.status.isActive {
                    VStack(alignment: .trailing, spacing: 4) {
                        SpeedBadge(speed: session.downloadSpeed, isUpload: false)
                        SpeedBadge(speed: session.uploadSpeed, isUpload: true)
                    }
                }
            }
            .padding(Theme.spacing12)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusLarge)
                    .fill(Theme.surfaceElevated.opacity(isPressed ? 0.8 : 1.0))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusLarge)
                            .stroke(
                                session.status.isActive
                                    ? Theme.accent.opacity(0.2)
                                    : Theme.glassBorder,
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(Theme.snappy, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .contextMenu {
            TorrentContextMenu(session: session)
        }
    }
}

// MARK: - Context Menu
struct TorrentContextMenu: View {
    @ObservedObject var session: TorrentSession

    var body: some View {
        Group {
            if session.status == .downloading || session.status == .connecting {
                Button { session.pause() } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            if session.status == .paused || session.status == .stopped {
                Button { session.start() } label: {
                    Label("Resume", systemImage: "play.fill")
                }
            }
            Button { session.stop() } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            Divider()
            Button(role: .destructive) {
                TorrentEngine.shared.remove(session: session, deleteFiles: false)
            } label: {
                Label("Remove", systemImage: "trash")
            }
            Button(role: .destructive) {
                TorrentEngine.shared.remove(session: session, deleteFiles: true)
            } label: {
                Label("Remove & Delete Files", systemImage: "trash.fill")
            }
        }
    }
}
