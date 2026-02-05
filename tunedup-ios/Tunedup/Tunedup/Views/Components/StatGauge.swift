import SwiftUI

// MARK: - Stat Gauge Component
// Animated circular progress with before/after values

struct StatGauge: View {
    let title: String
    let beforeValue: Int
    let afterValue: Int
    let unit: String
    let color: Color

    private static let goldColor = Color(hex: "FFD700")

    @State private var animatedProgress: Double = 0

    private var gain: Int {
        afterValue - beforeValue
    }

    // Stock = 50% fill. 2x stock = 100%. Clamped at 1.0.
    private var progress: Double {
        guard beforeValue > 0 else { return 0 }
        return min(Double(afterValue) / Double(beforeValue * 2), 1.0)
    }

    // True when after value >= 2x stock
    private var isOverflow: Bool {
        guard beforeValue > 0 else { return false }
        return afterValue >= beforeValue * 2
    }

    private var ringColor: Color {
        isOverflow ? Self.goldColor : color
    }

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.sm) {
            // Circular gauge
            ZStack {
                // Background ring
                Circle()
                    .stroke(
                        TunedUpTheme.Colors.textTertiary.opacity(0.2),
                        lineWidth: 8
                    )

                // Progress ring
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor.opacity(0.5), radius: 4)

                // Center content
                VStack(spacing: 2) {
                    Text("\(afterValue)")
                        .font(TunedUpTheme.Typography.dataMedium)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    Text(unit)
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                }
            }
            .frame(width: 100, height: 100)

            // Labels
            VStack(spacing: 4) {
                Text(title)
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)

                HStack(spacing: 4) {
                    Text("+\(gain)")
                        .font(TunedUpTheme.Typography.dataCaption)
                        .foregroundColor(ringColor)

                    Text("from \(beforeValue)")
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                }
            }
        }
        .onAppear {
            withAnimation(TunedUpTheme.Animation.spring.delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: afterValue) { _, _ in
            withAnimation(TunedUpTheme.Animation.spring) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Horizontal Stat Bar

struct StatBar: View {
    let label: String
    let value: String
    let subValue: String?
    let color: Color
    let progress: Double

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            HStack {
                Text(label)
                    .font(TunedUpTheme.Typography.subheadline)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)

                Spacer()

                HStack(spacing: 4) {
                    Text(value)
                        .font(TunedUpTheme.Typography.dataSmall)
                        .foregroundColor(color)

                    if let sub = subValue {
                        Text(sub)
                            .font(TunedUpTheme.Typography.caption)
                            .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    }
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TunedUpTheme.Colors.textTertiary.opacity(0.2))

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * animatedProgress)
                        .shadow(color: color.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            withAnimation(TunedUpTheme.Animation.spring.delay(0.1)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Quick Stat Display

struct QuickStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: TunedUpTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(TunedUpTheme.Typography.dataSmall)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                Text(label)
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
            }
        }
    }
}

// MARK: - Before/After Comparison

struct BeforeAfterStat: View {
    let label: String
    let before: String
    let after: String
    let improvement: String

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.sm) {
            Text(label)
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)

            HStack(spacing: TunedUpTheme.Spacing.sm) {
                // Before
                VStack(spacing: 2) {
                    Text(before)
                        .font(TunedUpTheme.Typography.dataSmall)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("STOCK")
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                }

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(TunedUpTheme.Colors.cyan)

                // After
                VStack(spacing: 2) {
                    Text(after)
                        .font(TunedUpTheme.Typography.dataSmall)
                        .foregroundColor(TunedUpTheme.Colors.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("MODDED")
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.cyan.opacity(0.7))
                }
            }

            // Improvement badge
            Text(improvement)
                .font(TunedUpTheme.Typography.dataCaption)
                .foregroundColor(TunedUpTheme.Colors.success)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, TunedUpTheme.Spacing.sm)
                .padding(.vertical, TunedUpTheme.Spacing.xs)
                .background(TunedUpTheme.Colors.success.opacity(0.15))
                .cornerRadius(TunedUpTheme.Radius.small)
        }
        .frame(maxWidth: .infinity)
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        TunedUpTheme.Colors.pureBlack.ignoresSafeArea()

        VStack(spacing: 32) {
            HStack(spacing: 24) {
                StatGauge(
                    title: "Horsepower",
                    beforeValue: 205,
                    afterValue: 255,
                    unit: "HP",
                    color: TunedUpTheme.Colors.cyan
                )

                StatGauge(
                    title: "Torque",
                    beforeValue: 192,
                    afterValue: 230,
                    unit: "LB-FT",
                    color: TunedUpTheme.Colors.magenta
                )
            }

            VStack(spacing: 16) {
                StatBar(
                    label: "Power",
                    value: "+50 HP",
                    subValue: "255 total",
                    color: TunedUpTheme.Colors.cyan,
                    progress: 0.7
                )

                StatBar(
                    label: "Handling",
                    value: "Improved",
                    subValue: nil,
                    color: TunedUpTheme.Colors.magenta,
                    progress: 0.5
                )
            }
            .padding(.horizontal)

            BeforeAfterStat(
                label: "0-60 MPH",
                before: "6.2s",
                after: "5.4s",
                improvement: "-0.8s faster"
            )
        }
        .padding()
    }
}
