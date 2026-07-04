import SwiftUI
import Charts

// MARK: - App Theme
public enum Theme {
    // MARK: - Mode Detection
    public static var isDark: Bool {
        let setting = SettingsManager.shared.colorScheme
        if setting == "dark" { return true }
        if setting == "light" { return false }
        // System mode — get from the active window scene's trait collection
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return scene.traitCollection.userInterfaceStyle == .dark
        }
        return false
    }

    // MARK: - Colors
    public static var background: Color {
        isDark ? Color(red: 0.05, green: 0.05, blue: 0.12) : Color(red: 0.94, green: 0.95, blue: 0.97)
    }
    public static var surface: Color {
        isDark ? Color(red: 0.1, green: 0.1, blue: 0.18) : Color(red: 1.0, green: 1.0, blue: 1.0)
    }
    public static var surfaceElevated: Color {
        isDark ? Color(red: 0.13, green: 0.13, blue: 0.22) : Color(red: 0.97, green: 0.97, blue: 0.98)
    }
    public static let accent = Color(red: 0.0, green: 0.7, blue: 0.95)        // Cyan
    public static let accentSecondary = Color(red: 0.4, green: 0.3, blue: 1.0) // Purple
    public static let accentTertiary = Color(red: 0.0, green: 0.8, blue: 0.5)  // Mint
    public static let downloadColor = Color(red: 0.0, green: 0.6, blue: 1.0)
    public static let uploadColor = Color(red: 0.2, green: 0.9, blue: 0.4)
    public static let warningColor = Color(red: 1.0, green: 0.7, blue: 0.0)
    public static let errorColor = Color(red: 1.0, green: 0.3, blue: 0.3)
    public static var textPrimary: Color {
        isDark ? .white : Color(red: 0.08, green: 0.08, blue: 0.12)
    }
    public static var textSecondary: Color {
        isDark ? .white.opacity(0.65) : Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.65)
    }
    public static var textTertiary: Color {
        isDark ? .white.opacity(0.4) : Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.4)
    }
    public static var divider: Color {
        isDark ? .white.opacity(0.08) : .black.opacity(0.08)
    }
    public static var glassBorder: Color {
        isDark ? .white.opacity(0.12) : .black.opacity(0.08)
    }

    // MARK: - Gradients
    public static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var backgroundGradient: LinearGradient {
        isDark
            ? LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.12),
                    Color(red: 0.06, green: 0.04, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            : LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.95, blue: 0.97),
                    Color(red: 0.92, green: 0.93, blue: 0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
    }

    public static var downloadGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.0, green: 0.6, blue: 1.0), Color(red: 0.2, green: 0.4, blue: 1.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Typography
    public static func titleFont(size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    public static func headlineFont(size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    public static func bodyFont(size: CGFloat = 14) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    public static func captionFont(size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    public static func monoFont(size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    // MARK: - Spacing
    public static let spacing2: CGFloat = 2
    public static let spacing4: CGFloat = 4
    public static let spacing8: CGFloat = 8
    public static let spacing12: CGFloat = 12
    public static let spacing16: CGFloat = 16
    public static let spacing20: CGFloat = 20
    public static let spacing24: CGFloat = 24
    public static let spacing32: CGFloat = 32

    // MARK: - Corner Radius
    public static let radiusSmall: CGFloat = 8
    public static let radiusMedium: CGFloat = 12
    public static let radiusLarge: CGFloat = 16
    public static let radiusXL: CGFloat = 20
    public static let radiusFull: CGFloat = 100

    // MARK: - Animation
    public static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.75)
    public static let smooth = Animation.easeInOut(duration: 0.25)
    public static let bounce = Animation.spring(response: 0.5, dampingFraction: 0.65)
}

// MARK: - Glass Morphism Modifier
public struct GlassMorphism: ViewModifier {
    var cornerRadius: CGFloat
    var opacity: Double

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Theme.surface.opacity(opacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Theme.glassBorder, lineWidth: 1)
                    )
            )
    }
}

public extension View {
    func glassMorphism(cornerRadius: CGFloat = Theme.radiusLarge, opacity: Double = 0.6) -> some View {
        modifier(GlassMorphism(cornerRadius: cornerRadius, opacity: opacity))
    }

    func cardStyle(padding: CGFloat = Theme.spacing16) -> some View {
        self
            .padding(padding)
            .glassMorphism()
    }

    func bounceSymbolEffect(value: some Equatable) -> AnyView {
        if #available(iOS 17.0, *) {
            return AnyView(self.symbolEffect(.bounce, value: value))
        }
        return AnyView(self)
    }
}
