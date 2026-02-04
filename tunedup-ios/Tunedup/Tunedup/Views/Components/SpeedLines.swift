import SwiftUI

// MARK: - Speed Lines Background
// Animated speed lines flowing left to right

struct SpeedLinesBackground: View {
    let lineCount: Int
    let isAnimating: Bool

    @State private var offsets: [CGFloat] = []

    init(lineCount: Int = 8, isAnimating: Bool = true) {
        self.lineCount = lineCount
        self.isAnimating = isAnimating
        _offsets = State(initialValue: Array(repeating: 0, count: lineCount))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<lineCount, id: \.self) { index in
                    SpeedLine(
                        yPosition: CGFloat.random(in: 0...geometry.size.height),
                        width: CGFloat.random(in: 50...150),
                        opacity: Double.random(in: 0.03...0.08),
                        delay: Double(index) * 0.2
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SpeedLine: View {
    let yPosition: CGFloat
    let width: CGFloat
    let opacity: Double
    let delay: Double

    @State private var offset: CGFloat = -200

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            TunedUpTheme.Colors.cyan.opacity(0),
                            TunedUpTheme.Colors.cyan.opacity(opacity),
                            TunedUpTheme.Colors.cyan.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 1)
                .position(x: offset, y: yPosition)
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: false)
                            .delay(delay)
                    ) {
                        offset = geometry.size.width + 200
                    }
                }
        }
    }
}

// MARK: - Gradient Overlay

struct TopGradientOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [
                TunedUpTheme.Colors.pureBlack,
                TunedUpTheme.Colors.pureBlack.opacity(0.8),
                TunedUpTheme.Colors.pureBlack.opacity(0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 150)
        .allowsHitTesting(false)
    }
}

struct BottomGradientOverlay: View {
    var body: some View {
        LinearGradient(
            colors: [
                TunedUpTheme.Colors.pureBlack.opacity(0),
                TunedUpTheme.Colors.pureBlack.opacity(0.8),
                TunedUpTheme.Colors.pureBlack
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 150)
        .allowsHitTesting(false)
    }
}

// MARK: - Glow Orb Background

struct GlowOrbBackground: View {
    let color: Color
    let size: CGFloat
    let position: CGPoint

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.15),
                        color.opacity(0.05),
                        color.opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .position(position)
            .blur(radius: 30)
            .onAppear {
                withAnimation(
                    Animation.easeInOut(duration: 4).repeatForever(autoreverses: true)
                ) {
                    scale = 1.2
                }
            }
    }
}

// MARK: - Noise Texture Overlay

struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<1000 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let opacity = Double.random(in: 0.02...0.05)

                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(Color.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        TunedUpTheme.Colors.pureBlack.ignoresSafeArea()

        SpeedLinesBackground()

        GlowOrbBackground(
            color: TunedUpTheme.Colors.cyan,
            size: 400,
            position: CGPoint(x: 300, y: 200)
        )

        GlowOrbBackground(
            color: TunedUpTheme.Colors.magenta,
            size: 300,
            position: CGPoint(x: 100, y: 500)
        )

        VStack {
            Spacer()

            Text("TunedUp")
                .font(TunedUpTheme.Typography.heroTitle)
                .foregroundColor(TunedUpTheme.Colors.textPrimary)

            Spacer()
        }
    }
}
