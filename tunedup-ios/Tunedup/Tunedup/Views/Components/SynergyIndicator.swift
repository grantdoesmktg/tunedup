import SwiftUI

// MARK: - Synergy Indicator
// Pulsing connection lines between related mods

struct SynergyIndicator: View {
    let synergyGroup: SynergyGroup
    let isExpanded: Bool

    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            // Header
            HStack(spacing: TunedUpTheme.Spacing.sm) {
                // Pulsing circuit icon
                ZStack {
                    Circle()
                        .fill(TunedUpTheme.Colors.magenta.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Circle()
                        .fill(TunedUpTheme.Colors.magenta.opacity(isPulsing ? 0.4 : 0.1))
                        .frame(width: 32, height: 32)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)

                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(TunedUpTheme.Colors.magenta)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(synergyGroup.name)
                        .font(TunedUpTheme.Typography.bodyBold)
                        .foregroundColor(TunedUpTheme.Colors.magenta)

                    Text("\(synergyGroup.modIds.count) mods linked")
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
            }

            // Explanation (when expanded)
            if isExpanded {
                Text(synergyGroup.explanation)
                    .font(TunedUpTheme.Typography.footnote)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .padding(.leading, 44)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.magenta.opacity(0.05))
        .cornerRadius(TunedUpTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                .stroke(TunedUpTheme.Colors.magenta.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
            ) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Synergy Connection Line

struct SynergyConnectionLine: View {
    let color: Color
    let isAnimating: Bool

    @State private var dashOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round,
                    dash: [6, 4],
                    dashPhase: dashOffset
                )
            )
        }
        .frame(height: 2)
        .onAppear {
            if isAnimating {
                withAnimation(
                    Animation.linear(duration: 1).repeatForever(autoreverses: false)
                ) {
                    dashOffset = -10
                }
            }
        }
    }
}

// MARK: - Mod Synergy Badge

struct ModSynergyBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.system(size: 10, weight: .semibold))

            Text("×\(count)")
                .font(TunedUpTheme.Typography.caption)
        }
        .foregroundColor(TunedUpTheme.Colors.magenta)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(TunedUpTheme.Colors.magenta.opacity(0.15))
        .cornerRadius(TunedUpTheme.Radius.small)
    }
}

// MARK: - Circuit Trace Background

struct CircuitTraceBackground: View {
    let isAnimating: Bool

    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Static traces
                ForEach(0..<5, id: \.self) { index in
                    CircuitTracePath(
                        startY: CGFloat(index) * (geometry.size.height / 5) + 20,
                        width: geometry.size.width,
                        nodeCount: 3 + index % 2
                    )
                    .stroke(
                        TunedUpTheme.Colors.magenta.opacity(0.1),
                        lineWidth: 1.5
                    )
                }

                // Animated trace (energy flowing)
                if isAnimating {
                    CircuitTracePath(
                        startY: geometry.size.height / 2,
                        width: geometry.size.width,
                        nodeCount: 4
                    )
                    .trim(from: 0, to: progress)
                    .stroke(
                        TunedUpTheme.Colors.magenta.opacity(0.5),
                        lineWidth: 2
                    )
                    .shadow(color: TunedUpTheme.Colors.magenta.opacity(0.5), radius: 4)
                }
            }
        }
        .onAppear {
            if isAnimating {
                withAnimation(
                    Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)
                ) {
                    progress = 1.0
                }
            }
        }
    }
}

struct CircuitTracePath: Shape {
    let startY: CGFloat
    let width: CGFloat
    let nodeCount: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let segmentWidth = width / CGFloat(nodeCount + 1)
        var currentX: CGFloat = 0
        var currentY = startY

        path.move(to: CGPoint(x: 0, y: currentY))

        for i in 0..<nodeCount {
            // Move horizontally
            currentX += segmentWidth
            path.addLine(to: CGPoint(x: currentX, y: currentY))

            // Add node (small circle connection point)
            path.addEllipse(in: CGRect(
                x: currentX - 3,
                y: currentY - 3,
                width: 6,
                height: 6
            ))

            // Random vertical offset for next segment
            let offset: CGFloat = (i % 2 == 0) ? 15 : -15
            currentY += offset
        }

        // Final horizontal line
        path.move(to: CGPoint(x: currentX, y: currentY))
        path.addLine(to: CGPoint(x: width, y: currentY))

        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        TunedUpTheme.Colors.pureBlack.ignoresSafeArea()

        VStack(spacing: 24) {
            SynergyIndicator(
                synergyGroup: SynergyGroup(
                    id: "breathing",
                    name: "Breathing Package",
                    modIds: ["intake", "exhaust", "tune"],
                    explanation: "Cold air intake + exhaust unlocks tune potential. Together these mods work synergistically to improve airflow and allow for more aggressive tuning."
                ),
                isExpanded: true
            )

            SynergyIndicator(
                synergyGroup: SynergyGroup(
                    id: "suspension",
                    name: "Handling Setup",
                    modIds: ["coilovers", "sway-bars"],
                    explanation: "Coilovers and sway bars together dramatically improve body control."
                ),
                isExpanded: false
            )

            HStack {
                Text("Cold Air Intake")
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                Spacer()

                ModSynergyBadge(count: 2)
            }
            .padding()
            .background(TunedUpTheme.Colors.cardSurface)
            .cornerRadius(TunedUpTheme.Radius.medium)

            // Circuit trace demo
            CircuitTraceBackground(isAnimating: true)
                .frame(height: 100)
                .padding()
        }
        .padding()
    }
}
