import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Bundle
@main
struct iTorrentFlowLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TorrentLiveActivityWidget()
    }
}

// MARK: - Widget
struct TorrentLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TorrentLiveActivityAttributes.self) { context in
            // Lock Screen / Banner view
            TorrentLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (long-press)
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
            } compactLeading: {
                // Compact leading — small progress arc
                CompactProgressArc(progress: context.state.progress)
            } compactTrailing: {
                // Compact trailing — speed
                Text(context.state.formattedDownloadSpeed)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
                    .minimumScaleFactor(0.5)
            } minimal: {
                // Minimal — tiny arc
                CompactProgressArc(progress: context.state.progress)
            }
        }
    }
}

// MARK: - Lock Screen View
struct TorrentLockScreenView: View {
    let context: ActivityViewContext<TorrentLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)
                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))
                Text(context.state.formattedProgress)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.torrentName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.state.statusLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Label(context.state.formattedDownloadSpeed, systemImage: "arrow.down")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.cyan)
                Label(context.state.formattedUploadSpeed, systemImage: "arrow.up")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.green.opacity(0.8))
                Text("ETA: \(context.state.eta)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Pause button on lock screen
            if let tid = context.attributes.torrentID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                Link(destination: URL(string: "itorrentflow://togglepause?torrentID=\(tid)")!) {
                    Image(systemName: context.state.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(context.state.isPaused ? .cyan : .orange)
                }
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.02, green: 0.08, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Compact Progress Arc
struct CompactProgressArc: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 18, height: 18)
    }
}

// MARK: - Expanded Regions
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<TorrentLiveActivityAttributes>

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: context.state.progress)
                .stroke(
                    LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(context.state.formattedProgress)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 44, height: 44)
        .padding(.leading, 8)
    }
}

struct ExpandedTrailingView: View {
    let context: ActivityViewContext<TorrentLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Label(context.state.formattedDownloadSpeed, systemImage: "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.cyan)
            Label(context.state.formattedUploadSpeed, systemImage: "arrow.up.circle.fill")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.green)
        }
        .padding(.trailing, 8)
    }
}

struct ExpandedCenterView: View {
    let context: ActivityViewContext<TorrentLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 1) {
            Text(context.attributes.torrentName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

struct ExpandedBottomView: View {
    let context: ActivityViewContext<TorrentLiveActivityAttributes>

    var body: some View {
        HStack {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * context.state.progress, height: 6)
                }
            }
            .frame(height: 6)

            Spacer(minLength: 8)

            Text("ETA \(context.state.eta)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            Image(systemName: "person.2.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
            Text("\(context.state.connectedPeers)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            // Pause/Resume Button
            if let torrentID = context.attributes.torrentID.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                Link(destination: URL(string: "itorrentflow://togglepause?torrentID=\(torrentID)")!) {
                    Image(systemName: context.state.isPaused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(context.state.isPaused ? .cyan : .orange)
                        .symbolRenderingMode(.hierarchical)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
