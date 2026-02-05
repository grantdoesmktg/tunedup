import SwiftUI

// MARK: - TunedUp Design System
// Street Racing Minimal - Fast, aggressive, no-BS

enum TunedUpTheme {

    // MARK: - Colors
    enum Colors {
        // Primary Brand Colors
        static let cyan = Color(hex: "00D9FF")
        static let magenta = Color(hex: "E91E8C")

        // Backgrounds
        static let pureBlack = Color(hex: "000000")
        static let darkSurface = Color(hex: "0F0F0F")
        static let cardSurface = Color(hex: "1A1A1A")
        static let elevatedSurface = Color(hex: "222222")

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "888888")
        static let textTertiary = Color(hex: "555555")

        // Semantic
        static let success = Color(hex: "10B981")
        static let warning = Color(hex: "F59E0B")
        static let error = Color(hex: "EF4444")

        // Gradients
        static let brandGradient = LinearGradient(
            colors: [cyan, magenta],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let cyanGlow = LinearGradient(
            colors: [cyan.opacity(0.8), cyan.opacity(0.2)],
            startPoint: .top,
            endPoint: .bottom
        )

        static let cardGradient = LinearGradient(
            colors: [cardSurface, darkSurface],
            startPoint: .top,
            endPoint: .bottom
        )

        static let circuitGradient = LinearGradient(
            colors: [magenta.opacity(0.6), magenta.opacity(0.1)],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let atmosphericGradient = LinearGradient(
            colors: [
                darkSurface.opacity(0.5),
                pureBlack,
                darkSurface.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography
    enum Typography {
        // Headers - SF Pro Display Bold
        static let heroTitle = Font.system(size: 48, weight: .bold, design: .default)
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)

        // Body - SF Pro Text
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)

        // Data/Numbers - SF Mono Bold (for alignment)
        static let dataHero = Font.system(size: 48, weight: .bold, design: .monospaced)
        static let dataLarge = Font.system(size: 32, weight: .bold, design: .monospaced)
        static let dataMedium = Font.system(size: 24, weight: .bold, design: .monospaced)
        static let dataSmall = Font.system(size: 18, weight: .semibold, design: .monospaced)
        static let dataCaption = Font.system(size: 14, weight: .medium, design: .monospaced)

        // Buttons
        static let button = Font.system(size: 17, weight: .semibold, design: .default)
        static let buttonSmall = Font.system(size: 15, weight: .semibold, design: .default)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Corner Radius
    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 100
    }

    // MARK: - Shadows
    enum Shadows {
        static let glow = Color(hex: "00D9FF").opacity(0.3)
        static let magentaGlow = Color(hex: "E91E8C").opacity(0.3)

        static func cyanGlow(radius: CGFloat = 20) -> some View {
            EmptyView()
        }
    }

    // MARK: - Animation
    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.7)
        static let springFast = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let springBouncy = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.3)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.25)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct AtmosphericBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            // Base black
            TunedUpTheme.Colors.pureBlack
                .ignoresSafeArea()

            // Atmospheric gradient
            TunedUpTheme.Colors.atmosphericGradient
                .ignoresSafeArea()

            // Glow orbs
            GeometryReader { geometry in
                GlowOrbBackground(
                    color: TunedUpTheme.Colors.cyan,
                    size: 300,
                    position: CGPoint(x: geometry.size.width * 0.3, y: geometry.size.height * 0.2)
                )

                GlowOrbBackground(
                    color: TunedUpTheme.Colors.magenta,
                    size: 250,
                    position: CGPoint(x: geometry.size.width * 0.7, y: geometry.size.height * 0.7)
                )
            }

            // Noise texture
            NoiseOverlay()
                .opacity(0.4)

            // Content
            content
        }
    }
}

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: radius / 2, x: 0, y: 0)
            .shadow(color: color.opacity(0.5), radius: radius, x: 0, y: 0)
    }
}

struct CardStyle: ViewModifier {
    var isElevated: Bool = false

    func body(content: Content) -> some View {
        content
            .background(isElevated ? TunedUpTheme.Colors.elevatedSurface : TunedUpTheme.Colors.cardSurface)
            .cornerRadius(TunedUpTheme.Radius.large)
            .overlay(
                RoundedRectangle(cornerRadius: TunedUpTheme.Radius.large)
                    .stroke(TunedUpTheme.Colors.textTertiary.opacity(0.2), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TunedUpTheme.Typography.button)
            .foregroundColor(TunedUpTheme.Colors.pureBlack)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                isEnabled ? TunedUpTheme.Colors.cyan : TunedUpTheme.Colors.textTertiary
            )
            .cornerRadius(TunedUpTheme.Radius.medium)
            .shadow(color: isEnabled ? TunedUpTheme.Colors.cyan.opacity(0.4) : .clear, radius: 12, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(TunedUpTheme.Animation.springFast, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TunedUpTheme.Typography.button)
            .foregroundColor(TunedUpTheme.Colors.cyan)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(TunedUpTheme.Colors.cardSurface)
            .cornerRadius(TunedUpTheme.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                    .stroke(TunedUpTheme.Colors.cyan, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(TunedUpTheme.Animation.springFast, value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TunedUpTheme.Typography.buttonSmall)
            .foregroundColor(TunedUpTheme.Colors.textSecondary)
            .padding(.horizontal, TunedUpTheme.Spacing.md)
            .padding(.vertical, TunedUpTheme.Spacing.sm)
            .background(configuration.isPressed ? TunedUpTheme.Colors.cardSurface : .clear)
            .cornerRadius(TunedUpTheme.Radius.small)
            .animation(TunedUpTheme.Animation.easeOut, value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func atmosphericBackground() -> some View {
        modifier(AtmosphericBackgroundModifier())
    }

    func glow(color: Color = TunedUpTheme.Colors.cyan, radius: CGFloat = 20) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }

    func cardStyle(elevated: Bool = false) -> some View {
        modifier(CardStyle(isElevated: elevated))
    }

    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Haptics Helper

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
