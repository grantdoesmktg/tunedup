import SwiftUI

// MARK: - Install Guide Sheet
// Displays AI-generated installation instructions for a mod

struct InstallGuideSheet: View {
    let build: Build
    let mod: Mod
    let execution: ModExecution?

    @StateObject private var viewModel = InstallGuideViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TunedUpTheme.Colors.pureBlack
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingGuideView()
                } else if let guide = viewModel.guide {
                    InstallGuideContent(guide: guide)
                } else if let error = viewModel.error {
                    GuideErrorView(
                        message: error,
                        onRetry: {
                            Task {
                                await viewModel.generateGuide(buildId: build.id, modId: mod.id)
                            }
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Install Guide")
                            .font(TunedUpTheme.Typography.bodyBold)
                            .foregroundColor(TunedUpTheme.Colors.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Haptics.impact(.light)
                        dismiss()
                    }
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.cyan)
                }
            }
            .toolbarBackground(TunedUpTheme.Colors.pureBlack, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            await viewModel.generateGuide(buildId: build.id, modId: mod.id)
        }
    }
}

// MARK: - Loading Guide View

struct LoadingGuideView: View {
    @State private var dots = ""

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            // Animated wrench icon
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundColor(TunedUpTheme.Colors.cyan)
                .rotationEffect(.degrees(-15))

            VStack(spacing: TunedUpTheme.Spacing.sm) {
                Text("Generating Install Guide")
                    .font(TunedUpTheme.Typography.title3)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                Text("Our mechanic is writing up the steps\(dots)")
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
            }

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: TunedUpTheme.Colors.cyan))
        }
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            if dots.count >= 3 {
                dots = ""
            } else {
                dots += "."
            }
        }
    }
}

// MARK: - Install Guide Content

struct InstallGuideContent: View {
    let guide: InstallGuide

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.lg) {
                // Title
                Text(guide.title)
                    .font(TunedUpTheme.Typography.title2)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                // Shop recommendation warning
                if guide.recommendation == .shop {
                    ShopRecommendationBanner(reason: guide.shopReason)
                }

                // Quick stats
                QuickStatsRow(guide: guide)

                // Tools needed
                if !guide.tools.isEmpty {
                    ToolsSection(tools: guide.tools)
                }

                // Steps
                if !guide.steps.isEmpty {
                    StepsSection(steps: guide.steps)
                }

                // Tips
                if !guide.tips.isEmpty {
                    TipsSection(tips: guide.tips)
                }

                // Warnings
                if !guide.warnings.isEmpty {
                    WarningsSection(warnings: guide.warnings)
                }

                // Bottom padding
                Color.clear.frame(height: TunedUpTheme.Spacing.xl)
            }
            .padding(TunedUpTheme.Spacing.lg)
        }
    }
}

// MARK: - Shop Recommendation Banner

struct ShopRecommendationBanner: View {
    let reason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 16))
                Text("Shop Recommended")
                    .font(TunedUpTheme.Typography.bodyBold)
            }
            .foregroundColor(TunedUpTheme.Colors.warning)

            Text(reason ?? "This install requires specialized equipment or expertise that's typically only found at a shop.")
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.warning.opacity(0.1))
        .cornerRadius(TunedUpTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                .stroke(TunedUpTheme.Colors.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Quick Stats Row

struct QuickStatsRow: View {
    let guide: InstallGuide

    var body: some View {
        HStack(spacing: TunedUpTheme.Spacing.md) {
            // Time estimate
            StatPill(icon: "clock", text: guide.timeEstimate)

            // Difficulty
            StatPill(
                icon: "speedometer",
                text: "Difficulty \(guide.difficulty)/5"
            )

            Spacer()
        }
    }
}

struct StatPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: TunedUpTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(TunedUpTheme.Typography.caption)
        }
        .foregroundColor(TunedUpTheme.Colors.textSecondary)
        .padding(.horizontal, TunedUpTheme.Spacing.sm)
        .padding(.vertical, TunedUpTheme.Spacing.xs)
        .background(TunedUpTheme.Colors.darkSurface)
        .cornerRadius(TunedUpTheme.Radius.small)
    }
}

// MARK: - Tools Section

struct ToolsSection: View {
    let tools: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            Text("TOOLS NEEDED")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .tracking(1)

            FlowLayoutForTools(spacing: TunedUpTheme.Spacing.sm) {
                ForEach(tools, id: \.self) { tool in
                    ToolChip(name: tool)
                }
            }
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
    }
}

struct ToolChip: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wrench")
                .font(.system(size: 10))
            Text(name)
                .font(TunedUpTheme.Typography.caption)
        }
        .foregroundColor(TunedUpTheme.Colors.cyan)
        .padding(.horizontal, TunedUpTheme.Spacing.sm)
        .padding(.vertical, 6)
        .background(TunedUpTheme.Colors.cyan.opacity(0.1))
        .cornerRadius(TunedUpTheme.Radius.small)
    }
}

// Simple flow layout for tools
struct FlowLayoutForTools: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Steps Section

struct StepsSection: View {
    let steps: [InstallStep]

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
            Text("STEPS")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .tracking(1)

            ForEach(steps) { step in
                StepCard(step: step)
            }
        }
    }
}

struct StepCard: View {
    let step: InstallStep

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            // Step number and title
            HStack(alignment: .top, spacing: TunedUpTheme.Spacing.sm) {
                // Step number badge
                Text("\(step.number)")
                    .font(TunedUpTheme.Typography.dataSmall)
                    .foregroundColor(TunedUpTheme.Colors.pureBlack)
                    .frame(width: 28, height: 28)
                    .background(TunedUpTheme.Colors.cyan)
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.xs) {
                    Text(step.title)
                        .font(TunedUpTheme.Typography.bodyBold)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    Text(step.description)
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                }
            }

            // Warning if present
            if let warning = step.warning {
                HStack(alignment: .top, spacing: TunedUpTheme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(TunedUpTheme.Colors.warning)

                    Text(warning)
                        .font(TunedUpTheme.Typography.footnote)
                        .foregroundColor(TunedUpTheme.Colors.warning)
                }
                .padding(TunedUpTheme.Spacing.sm)
                .background(TunedUpTheme.Colors.warning.opacity(0.1))
                .cornerRadius(TunedUpTheme.Radius.small)
            }
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
    }
}

// MARK: - Tips Section

struct TipsSection: View {
    let tips: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            Text("PRO TIPS")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .tracking(1)

            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: TunedUpTheme.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(TunedUpTheme.Colors.cyan)

                    Text(tip)
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                }
            }
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cyan.opacity(0.05))
        .cornerRadius(TunedUpTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                .stroke(TunedUpTheme.Colors.cyan.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Warnings Section

struct WarningsSection: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            Text("SAFETY WARNINGS")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .tracking(1)

            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: TunedUpTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(TunedUpTheme.Colors.error)

                    Text(warning)
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                }
            }
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.error.opacity(0.05))
        .cornerRadius(TunedUpTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                .stroke(TunedUpTheme.Colors.error.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Guide Error View

struct GuideErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(TunedUpTheme.Colors.error)

            Text("Couldn't Generate Guide")
                .font(TunedUpTheme.Typography.title2)
                .foregroundColor(TunedUpTheme.Colors.textPrimary)

            Text(message)
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TunedUpTheme.Spacing.xl)

            Button(action: onRetry) {
                Text("Try Again")
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(width: 150)
        }
        .padding(TunedUpTheme.Spacing.xl)
    }
}

// MARK: - Preview

#Preview {
    InstallGuideSheet(
        build: Build(
            id: "test",
            createdAt: "2026-02-09",
            pipelineStatus: .completed,
            failedStep: nil,
            vehicle: VehicleProfile(
                year: 2019,
                make: "Honda",
                model: "Civic",
                trim: "Si",
                engine: "1.5L Turbo",
                displacement: "1.5L",
                aspiration: .turbo,
                drivetrain: .fwd,
                transmission: .manual,
                factoryHp: 205,
                factoryTorque: 192,
                curbWeight: 2906,
                platform: nil
            ),
            intent: UserIntent(
                budget: 5000,
                priorityRank: ["power", "handling"],
                dailyDriver: true,
                emissionsSensitive: false,
                existingMods: [],
                city: nil
            ),
            strategy: nil,
            plan: nil,
            execution: nil,
            performance: nil,
            sourcing: nil,
            presentation: nil,
            assumptions: nil
        ),
        mod: Mod(
            id: "intake-1",
            category: "intake",
            name: "Cold Air Intake",
            description: "Aftermarket cold air intake system",
            justification: "Increases airflow for power gains",
            estimatedCost: CostRange(low: 250, high: 400),
            dependsOn: [],
            synergyWith: []
        ),
        execution: nil
    )
}
