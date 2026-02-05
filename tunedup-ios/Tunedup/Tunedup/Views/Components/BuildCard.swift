import SwiftUI

// MARK: - Build Card Component
// 3D tilted card with gradient border and stats overlay

struct BuildCard: View {
    let build: BuildSummary
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        ZStack {
            // Card Background
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.xl)
                .fill(TunedUpTheme.Colors.cardSurface)

            // Gradient border when selected
            if isSelected {
                RoundedRectangle(cornerRadius: TunedUpTheme.Radius.xl)
                    .stroke(TunedUpTheme.Colors.brandGradient, lineWidth: 2)
            }

            // Content
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
                // Status indicator
                HStack {
                    StatusBadge(status: build.pipelineStatus)
                    Spacer()
                    Text(formatDate(build.createdAt))
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                }

                Spacer()

                // Vehicle name
                VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.xs) {
                    Text(build.vehicle.displayName)
                        .font(TunedUpTheme.Typography.title2)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)
                        .lineLimit(1)

                    Text(build.vehicle.trim)
                        .font(TunedUpTheme.Typography.subheadline)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                // Stats preview
                if let stats = build.statsPreview {
                    HStack(spacing: TunedUpTheme.Spacing.lg) {
                        if let hpRange = stats.hpGainRange, hpRange.count == 2 {
                            StatPill(
                                label: "HP GAIN",
                                value: "+\(hpRange[0])-\(hpRange[1])",
                                color: TunedUpTheme.Colors.cyan
                            )
                        }
                        StatPill(
                            label: "BUDGET",
                            value: "$\(stats.totalBudget.formattedWithCommas)",
                            color: TunedUpTheme.Colors.magenta
                        )
                    }
                }

                // Summary text
                if let summary = build.summary {
                    Text(summary)
                        .font(TunedUpTheme.Typography.footnote)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                        .lineLimit(2)
                        .padding(.top, TunedUpTheme.Spacing.xs)
                }
            }
            .padding(TunedUpTheme.Spacing.lg)
        }
        .frame(height: 220)
        .contentShape(RoundedRectangle(cornerRadius: TunedUpTheme.Radius.xl))
        .onTapGesture {
            Haptics.impact(.medium)
            onTap()
        }
        .rotation3DEffect(
            .degrees(isSelected ? 0 : -2),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .shadow(
            color: isSelected ? TunedUpTheme.Colors.cyan.opacity(0.3) : Color.clear,
            radius: 20,
            y: 10
        )
        .animation(TunedUpTheme.Animation.spring, value: isSelected)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date.relativeFormatted
        }
        return dateString
    }
}

// MARK: - Supporting Components

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)

            Text(value)
                .font(TunedUpTheme.Typography.dataSmall)
                .foregroundColor(color)
        }
    }
}

struct StatusBadge: View {
    let status: PipelineStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .if(status == .running) { view in
                    view.overlay(
                        Circle()
                            .stroke(statusColor, lineWidth: 2)
                            .scaleEffect(1.5)
                            .opacity(0)
                            .animation(
                                Animation.easeOut(duration: 1).repeatForever(autoreverses: false),
                                value: UUID()
                            )
                    )
                }

            Text(statusText)
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, TunedUpTheme.Spacing.sm)
        .padding(.vertical, TunedUpTheme.Spacing.xs)
        .background(statusColor.opacity(0.15))
        .cornerRadius(TunedUpTheme.Radius.pill)
    }

    private var statusColor: Color {
        switch status {
        case .pending: return TunedUpTheme.Colors.textSecondary
        case .running: return TunedUpTheme.Colors.cyan
        case .completed: return TunedUpTheme.Colors.success
        case .failed: return TunedUpTheme.Colors.error
        }
    }

    private var statusText: String {
        switch status {
        case .pending: return "Pending"
        case .running: return "Building..."
        case .completed: return "Ready"
        case .failed: return "Failed"
        }
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(TunedUpTheme.Animation.springFast, value: configuration.isPressed)
    }
}

// MARK: - Empty State Card

struct EmptyBuildCard: View {
    let isEnabled: Bool
    var onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            TunedUpTheme.Colors.darkSurface,
                            TunedUpTheme.Colors.cardSurface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TunedUpTheme.Radius.xl)
                        .strokeBorder(
                            style: StrokeStyle(lineWidth: 2, dash: [10, 8])
                        )
                        .foregroundColor(
                            isEnabled
                                ? TunedUpTheme.Colors.textTertiary.opacity(0.7)
                                : TunedUpTheme.Colors.textTertiary.opacity(0.3)
                        )
                )

            VStack(spacing: TunedUpTheme.Spacing.md) {
                Image(systemName: "plus")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundColor(isEnabled ? TunedUpTheme.Colors.cyan : TunedUpTheme.Colors.textTertiary.opacity(0.6))

                Text(isEnabled ? "Create New Build" : "Build Limit Reached")
                    .font(TunedUpTheme.Typography.title3)
                    .foregroundColor(isEnabled ? TunedUpTheme.Colors.textPrimary : TunedUpTheme.Colors.textSecondary)

                Text(isEnabled ? "Swipe to add another build" : "Delete a build to add another")
                    .font(TunedUpTheme.Typography.footnote)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
            }
        }
        .frame(height: 220)
        .contentShape(RoundedRectangle(cornerRadius: TunedUpTheme.Radius.xl))
        .onTapGesture {
            if isEnabled {
                Haptics.impact(.light)
                onTap()
            }
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        TunedUpTheme.Colors.pureBlack.ignoresSafeArea()

        VStack(spacing: 20) {
            BuildCard(
                build: BuildSummary(
                    id: "1",
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    vehicle: VehicleSummary(year: 2019, make: "Honda", model: "Civic", trim: "Si"),
                    summary: "Street performance build focused on bolt-ons and handling upgrades.",
                    pipelineStatus: .completed,
                    statsPreview: StatsPreview(hpGainRange: [35, 50], totalBudget: 5000)
                ),
                isSelected: true,
                onTap: {}
            )

            EmptyBuildCard(isEnabled: true, onTap: {})
        }
        .padding()
    }
}
