import SwiftUI

public struct CircularProgressView: View {
    public let progress: Double
    public var size: CGFloat = 44
    public var lineWidth: CGFloat = 4
    public var showLabel: Bool = false
    public var color: Color = Theme.accent

    public init(progress: Double, size: CGFloat = 44, lineWidth: CGFloat = 4,
                showLabel: Bool = false, color: Color = Theme.accent) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.showLabel = showLabel
        self.color = color
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.separator).opacity(0.3), lineWidth: lineWidth)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(Theme.smooth, value: progress)
            if showLabel {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
    }
}

public struct SpeedBadge: View {
    let speed: Int64
    let isUpload: Bool

    private var icon: String { isUpload ? "arrow.up" : "arrow.down" }
    private var color: Color { isUpload ? Theme.uploadColor : Theme.downloadColor }

    public var body: some View {
        Label(
            ByteCountFormatter.string(fromByteCount: speed, countStyle: .binary) + "/s",
            systemImage: icon
        )
        .font(.caption2)
        .foregroundStyle(color)
    }
}

public struct StatusPill: View {
    let status: TorrentStatus

    public var body: some View {
        Label(status.label, systemImage: status.icon)
            .font(.caption)
            .foregroundStyle(status.color)
    }
}

public struct PieceVisualizerView: View {
    let pieces: [PieceStatus]
    var height: CGFloat = 12

    public var body: some View {
        Canvas { context, size in
            guard !pieces.isEmpty else { return }
            let pieceWidth = size.width / CGFloat(pieces.count)
            for (i, status) in pieces.enumerated() {
                let x = CGFloat(i) * pieceWidth
                let rect = CGRect(x: x, y: 0, width: max(1, pieceWidth - 0.5), height: size.height)
                let color: Color = switch status {
                case .verified: Theme.accent
                case .downloading: Theme.warningColor
                case .missing: Color(.separator).opacity(0.3)
                }
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

public struct GradientProgressBar: View {
    let progress: Double
    var color: Color = Theme.downloadColor

    public var body: some View {
        ProgressView(value: max(0, min(1, progress)))
            .tint(color)
    }
}

public struct InfoRow: View {
    let label: String
    let value: String
    var isMonospace: Bool = false

    public var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(isMonospace ? .system(.subheadline, design: .monospaced) : .subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
            Spacer()
        }
    }
}
