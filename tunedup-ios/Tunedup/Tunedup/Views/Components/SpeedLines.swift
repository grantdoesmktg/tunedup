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
    @State private var noisePoints: [(CGPoint, Double)] = []

    var body: some View {
        Canvas { context, size in
            // Use pre-generated noise points for better performance
            if noisePoints.isEmpty {
                // Generate on first render only
                return
            }

            for (point, opacity) in noisePoints {
                let scaledPoint = CGPoint(
                    x: point.x * size.width,
                    y: point.y * size.height
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: scaledPoint.x, y: scaledPoint.y, width: 1, height: 1)),
                    with: .color(Color.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            // Generate normalized noise points once
            if noisePoints.isEmpty {
                noisePoints = (0..<800).map { _ in
                    (
                        CGPoint(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...1)),
                        Double.random(in: 0.02...0.05)
                    )
                }
            }
        }
    }
}

// MARK: - Particle Snowfall Background

struct ParticleSnowfall: View {
    let particleCount: Int

    init(particleCount: Int = 40) {
        self.particleCount = particleCount
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<particleCount, id: \.self) { index in
                    SnowParticle(
                        screenSize: geometry.size,
                        color: index % 2 == 0 ? TunedUpTheme.Colors.cyan : TunedUpTheme.Colors.magenta,
                        index: index
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SnowParticle: View {
    let screenSize: CGSize
    let color: Color
    let index: Int

    @State private var yOffset: CGFloat = -50
    @State private var xDrift: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var isAnimating = false

    // Randomized per-particle properties
    private let startX: CGFloat
    private let size: CGFloat
    private let duration: Double
    private let initialDelay: Double
    private let driftAmount: CGFloat
    private let baseOpacity: Double

    init(screenSize: CGSize, color: Color, index: Int) {
        self.screenSize = screenSize
        self.color = color
        self.index = index

        // Generate stable random values per particle
        let seed = UInt64(index * 12345)
        var rng = SeededRandomNumberGenerator(seed: seed)

        self.startX = CGFloat.random(in: 0...1, using: &rng) * screenSize.width
        self.size = CGFloat.random(in: 2.5...5.0, using: &rng)
        self.duration = Double.random(in: 10...18, using: &rng)
        self.initialDelay = Double.random(in: 0...3, using: &rng)
        self.driftAmount = CGFloat.random(in: -40...40, using: &rng)
        self.baseOpacity = Double.random(in: 0.35...0.65, using: &rng)
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: size * 0.3)
            .opacity(opacity)
            .position(
                x: startX + xDrift,
                y: yOffset
            )
            .onAppear {
                startFalling()
            }
    }

    private func startFalling() {
        // Reset to top
        yOffset = -50
        xDrift = 0

        // Fade in quickly
        withAnimation(.easeIn(duration: 0.5).delay(initialDelay)) {
            opacity = baseOpacity
        }

        // Animate falling
        withAnimation(.linear(duration: duration).delay(initialDelay)) {
            yOffset = screenSize.height + 50
        }

        // Animate horizontal drift
        withAnimation(.easeInOut(duration: duration / 2).delay(initialDelay)) {
            xDrift = driftAmount
        }

        // Schedule the next fall cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + initialDelay + 0.1) {
            // Reset and restart (no initial delay on subsequent cycles)
            yOffset = -50
            xDrift = 0
            opacity = 0

            withAnimation(.easeIn(duration: 0.3)) {
                opacity = baseOpacity
            }

            withAnimation(.linear(duration: duration)) {
                yOffset = screenSize.height + 50
            }

            withAnimation(.easeInOut(duration: duration / 2)) {
                xDrift = -driftAmount // Alternate drift direction
            }

            // Continue the loop
            scheduleNextCycle()
        }
    }

    private func scheduleNextCycle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            yOffset = -50
            xDrift = 0
            opacity = 0

            withAnimation(.easeIn(duration: 0.3)) {
                opacity = baseOpacity
            }

            withAnimation(.linear(duration: duration)) {
                yOffset = screenSize.height + 50
            }

            withAnimation(.easeInOut(duration: duration / 2)) {
                xDrift = driftAmount
            }

            scheduleNextCycle()
        }
    }
}

// Simple seeded RNG for consistent particle randomization
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
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

        ParticleSnowfall()

        VStack {
            Spacer()

            Text("TunedUp")
                .font(TunedUpTheme.Typography.heroTitle)
                .foregroundColor(TunedUpTheme.Colors.textPrimary)

            Spacer()
        }
    }
}
