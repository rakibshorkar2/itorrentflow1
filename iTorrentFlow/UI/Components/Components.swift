import SwiftUI

// MARK: - Circular Progress View
public struct CircularProgressView: View {
    public let progress: Double          // 0.0 – 1.0
    public var size: CGFloat = 60
    public var lineWidth: CGFloat = 6
    public var showLabel: Bool = true
    public var gradient: [Color] = [Theme.accent, Theme.accentSecondary]

    public init(progress: Double, size: CGFloat = 60, lineWidth: CGFloat = 6,
                showLabel: Bool = true, gradient: [Color] = [Theme.accent, Theme.accentSecondary]) {
        self.progress = progress; self.size = size; self.lineWidth = lineWidth
        self.showLabel = showLabel; self.gradient = gradient
    }

    public var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Theme.surface, lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(Theme.smooth, value: progress)

            // Label
            if showLabel {
                Text("\(Int(progress * 100))%")
                    .font(Theme.captionFont(size: size * 0.18))
                    .foregroundStyle(Theme.textPrimary)
                    .fontWeight(.bold)
            }
        }
    }
}

// MARK: - Glass Card
public struct GlassCard<Content: View>: View {
    let content: () -> Content
    var padding: CGFloat = Theme.spacing16
    var cornerRadius: CGFloat = Theme.radiusLarge

    public init(padding: CGFloat = Theme.spacing16,
                cornerRadius: CGFloat = Theme.radiusLarge,
                @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        content()
            .padding(padding)
            .glassMorphism(cornerRadius: cornerRadius)
    }
}

// MARK: - Animated Speed Badge
public struct SpeedBadge: View {
    let speed: Int64
    let isUpload: Bool

    private var icon: String { isUpload ? "arrow.up" : "arrow.down" }
    private var color: Color { isUpload ? Theme.uploadColor : Theme.downloadColor }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(ByteCountFormatter.string(fromByteCount: speed, countStyle: .binary) + "/s")
                .font(Theme.captionFont(size: 11))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Status Pill
public struct StatusPill: View {
    let status: TorrentStatus

    public var body: some View {
        HStack(spacing: 4) {
            if status.isActive {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
                    .scaleEffect(status.isActive ? 1.0 : 0.8)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: status.isActive)
            }
            Text(status.label)
                .font(Theme.captionFont(size: 11))
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Piece Visualizer
public struct PieceVisualizerView: View {
    let pieces: [PieceStatus]
    var height: CGFloat = 8

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
                case .missing: Theme.surface
                }
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Seeder/Leecher Health View
public struct TorrentHealthView: View {
    let seeders: Int
    let leechers: Int

    private var ratio: Double {
        leechers > 0 ? Double(seeders) / Double(leechers) : Double(seeders > 0 ? 10 : 0)
    }
    private var healthColor: Color {
        if seeders > 50 { return .green }
        if seeders > 10 { return .yellow }
        return .red
    }

    public var body: some View {
        HStack(spacing: 8) {
            Label("\(seeders)", systemImage: "arrow.up.circle.fill")
                .font(Theme.captionFont(size: 11))
                .foregroundStyle(.green)
            Label("\(leechers)", systemImage: "arrow.down.circle.fill")
                .font(Theme.captionFont(size: 11))
                .foregroundStyle(.red)
        }
    }
}

// MARK: - Gradient Progress Bar
public struct GradientProgressBar: View {
    let progress: Double
    var height: CGFloat = 4
    var gradient: [Color] = [Theme.downloadColor, Theme.accentSecondary]

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.surface)
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, progress))), height: height)
                    .animation(Theme.smooth, value: progress)
            }
        }
        .frame(height: height)
    }
}
