import SwiftUI

public enum Theme {
    // MARK: - Accent Colors
    public static let accent = Color.blue
    public static let accentSecondary = Color.purple
    public static let accentTertiary = Color.green
    public static let downloadColor = Color.blue
    public static let uploadColor = Color.green
    public static let warningColor = Color.orange
    public static let errorColor = Color.red

    // MARK: - Typography
    public static func titleFont(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    public static func headlineFont(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
    public static func bodyFont(size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    public static func captionFont(size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }
    public static func monoFont(size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    // MARK: - Spacing
    public static let spacing8: CGFloat = 8
    public static let spacing12: CGFloat = 12
    public static let spacing16: CGFloat = 16
    public static let spacing20: CGFloat = 20
    public static let spacing24: CGFloat = 24
    public static let spacing32: CGFloat = 32

    // MARK: - Corner Radius
    public static let radiusMedium: CGFloat = 10
    public static let radiusLarge: CGFloat = 14

    // MARK: - Animation
    public static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
    public static let smooth = Animation.easeInOut(duration: 0.25)
}

public extension View {
    func bounceSymbolEffect(value: some Equatable) -> AnyView {
        if #available(iOS 17.0, *) {
            return AnyView(self.symbolEffect(.bounce, value: value))
        }
        return AnyView(self)
    }
}
