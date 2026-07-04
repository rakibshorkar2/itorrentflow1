import SwiftUI

public struct DownloadRowView: View {
    @ObservedObject var session: TorrentSession

    public var body: some View {
        HStack(spacing: 12) {
            CircularProgressView(
                progress: session.progress,
                size: 44,
                lineWidth: 3,
                showLabel: true,
                color: session.status.isActive ? Theme.accent : .secondary
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(session.metadata.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                GradientProgressBar(
                    progress: session.progress,
                    height: 4,
                    color: session.status.isActive ? Theme.downloadColor : .secondary
                )

                HStack(spacing: 6) {
                    StatusPill(status: session.status)

                    if session.metadata.totalSize > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: session.metadata.totalSize, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if session.status.isActive && session.connectedPeers > 0 {
                        Label("\(session.connectedPeers)", systemImage: "person.2.fill")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if session.status.isActive {
                VStack(alignment: .trailing, spacing: 2) {
                    SpeedBadge(speed: session.downloadSpeed, isUpload: false)
                    SpeedBadge(speed: session.uploadSpeed, isUpload: true)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TorrentContextMenu: View {
    @ObservedObject var session: TorrentSession

    var body: some View {
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
