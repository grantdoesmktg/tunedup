import SwiftUI

// MARK: - Build Tracker View
// Interactive checklist for tracking mod installation progress

struct BuildTrackerView: View {
    let build: Build
    @StateObject private var viewModel = BuildTrackerViewModel()
    @State private var selectedModForGuide: ModForGuide?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TunedUpTheme.Colors.pureBlack
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.progress.isEmpty {
                    LoadingView()
                } else {
                    ScrollView {
                        VStack(spacing: TunedUpTheme.Spacing.lg) {
                            // Progress summary card
                            if let stats = viewModel.stats {
                                ProgressSummaryCard(stats: stats)
                            }

                            // Stage sections
                            if let plan = build.plan {
                                ForEach(plan.stages) { stage in
                                    StageProgressSection(
                                        stage: stage,
                                        execution: build.execution,
                                        progress: viewModel.progress,
                                        onStatusChange: { modId, status in
                                            Task {
                                                await viewModel.updateProgress(modId: modId, status: status)
                                            }
                                        },
                                        onInstallGuideTap: { mod, execution in
                                            selectedModForGuide = ModForGuide(mod: mod, execution: execution)
                                        }
                                    )
                                }
                            }

                            // Bottom padding
                            Color.clear.frame(height: TunedUpTheme.Spacing.xl)
                        }
                        .padding(TunedUpTheme.Spacing.lg)
                    }
                }

                // Error toast
                if let error = viewModel.error {
                    VStack {
                        Spacer()
                        Text(error)
                            .font(TunedUpTheme.Typography.caption)
                            .foregroundColor(.white)
                            .padding(TunedUpTheme.Spacing.md)
                            .background(TunedUpTheme.Colors.error)
                            .cornerRadius(TunedUpTheme.Radius.medium)
                            .padding(.bottom, TunedUpTheme.Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Build Tracker")
                        .font(TunedUpTheme.Typography.title3)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Haptics.impact(.light)
                        dismiss()
                    }) {
                        HStack(spacing: TunedUpTheme.Spacing.xs) {
                            Image(systemName: "chevron.left")
                            Text("Build")
                        }
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    }
                }
            }
            .toolbarBackground(TunedUpTheme.Colors.pureBlack, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .sheet(item: $selectedModForGuide) { modForGuide in
            InstallGuideSheet(
                build: build,
                mod: modForGuide.mod,
                execution: modForGuide.execution
            )
        }
        .task {
            await viewModel.loadProgress(buildId: build.id)
        }
    }
}

// Helper struct to pass mod info to sheet
struct ModForGuide: Identifiable {
    var id: String { mod.id }
    let mod: Mod
    let execution: ModExecution?
}

// MARK: - Progress Summary Card

struct ProgressSummaryCard: View {
    let stats: ProgressStats

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.md) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: TunedUpTheme.Radius.small)
                        .fill(TunedUpTheme.Colors.darkSurface)

                    // Progress fill
                    RoundedRectangle(cornerRadius: TunedUpTheme.Radius.small)
                        .fill(
                            LinearGradient(
                                colors: [TunedUpTheme.Colors.cyan, TunedUpTheme.Colors.magenta],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(stats.percentComplete / 100))
                        .animation(TunedUpTheme.Animation.spring, value: stats.percentComplete)
                }
            }
            .frame(height: 8)

            // Stats row
            HStack {
                StatBadge(
                    label: "Total",
                    value: "\(stats.total)",
                    color: TunedUpTheme.Colors.textSecondary
                )

                Spacer()

                StatBadge(
                    label: "Purchased",
                    value: "\(stats.purchased)",
                    color: TunedUpTheme.Colors.warning
                )

                Spacer()

                StatBadge(
                    label: "Installed",
                    value: "\(stats.installed)",
                    color: TunedUpTheme.Colors.success
                )
            }

            // Percentage
            Text("\(Int(stats.percentComplete))% Complete")
                .font(TunedUpTheme.Typography.dataSmall)
                .foregroundColor(TunedUpTheme.Colors.cyan)
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(TunedUpTheme.Typography.dataMedium)
                .foregroundColor(color)
            Text(label)
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
        }
    }
}

// MARK: - Stage Progress Section

struct StageProgressSection: View {
    let stage: Stage
    let execution: ExecutionPlan?
    let progress: [String: ModProgress]
    let onStatusChange: (String, ProgressStatus) -> Void
    let onInstallGuideTap: (Mod, ModExecution?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
            // Stage header
            HStack {
                Text("STAGE \(stage.stageNumber)")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    .tracking(1)

                Text(stage.name)
                    .font(TunedUpTheme.Typography.bodyBold)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)

                Spacer()

                // Stage completion indicator
                let completedCount = stage.mods.filter { progress[$0.id]?.status == .installed }.count
                Text("\(completedCount)/\(stage.mods.count)")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(
                        completedCount == stage.mods.count
                            ? TunedUpTheme.Colors.success
                            : TunedUpTheme.Colors.textTertiary
                    )
            }

            // Mods list
            ForEach(stage.mods) { mod in
                ModProgressCard(
                    mod: mod,
                    execution: execution?.modExecutions.first { $0.modId == mod.id },
                    progress: progress[mod.id],
                    onStatusChange: { status in
                        onStatusChange(mod.id, status)
                    },
                    onInstallGuideTap: {
                        let exec = execution?.modExecutions.first { $0.modId == mod.id }
                        onInstallGuideTap(mod, exec)
                    }
                )
            }
        }
    }
}

// MARK: - Mod Progress Card

struct ModProgressCard: View {
    let mod: Mod
    let execution: ModExecution?
    let progress: ModProgress?
    let onStatusChange: (ProgressStatus) -> Void
    let onInstallGuideTap: () -> Void

    private var currentStatus: ProgressStatus {
        progress?.status ?? .pending
    }

    private var isShopRecommended: Bool {
        execution?.diyable == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
            // Header row
            HStack(alignment: .center) {
                // Checkbox
                ProgressCheckbox(
                    status: currentStatus,
                    onChange: onStatusChange
                )

                // Mod info
                VStack(alignment: .leading, spacing: 2) {
                    Text(mod.name)
                        .font(TunedUpTheme.Typography.bodyBold)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)
                        .strikethrough(currentStatus == .installed, color: TunedUpTheme.Colors.textTertiary)

                    Text(mod.estimatedCost.formatted)
                        .font(TunedUpTheme.Typography.dataCaption)
                        .foregroundColor(TunedUpTheme.Colors.cyan)
                }

                Spacer()

                // DIY/Shop badge
                if let exec = execution {
                    VStack(alignment: .trailing, spacing: 4) {
                        TrackerDIYBadge(diyable: exec.diyable, difficulty: exec.difficulty)
                    }
                }
            }

            // Install guide button
            Button(action: {
                Haptics.impact(.light)
                onInstallGuideTap()
            }) {
                HStack(spacing: TunedUpTheme.Spacing.xs) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 12))
                    Text("How to Install")
                        .font(TunedUpTheme.Typography.caption)
                    if isShopRecommended {
                        Text("(Shop Rec'd)")
                            .font(TunedUpTheme.Typography.caption)
                            .foregroundColor(TunedUpTheme.Colors.warning)
                    }
                }
                .foregroundColor(TunedUpTheme.Colors.cyan)
            }
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                .stroke(
                    currentStatus == .installed
                        ? TunedUpTheme.Colors.success.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Progress Checkbox

struct ProgressCheckbox: View {
    let status: ProgressStatus
    let onChange: (ProgressStatus) -> Void

    var body: some View {
        Menu {
            Button {
                Haptics.selection()
                onChange(.pending)
            } label: {
                Label("Not Started", systemImage: status == .pending ? "checkmark" : "")
            }

            Button {
                Haptics.selection()
                onChange(.purchased)
            } label: {
                Label("Purchased", systemImage: status == .purchased ? "checkmark" : "")
            }

            Button {
                Haptics.selection()
                onChange(.installed)
            } label: {
                Label("Installed", systemImage: status == .installed ? "checkmark" : "")
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 28, height: 28)

                if status == .installed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(TunedUpTheme.Colors.success)
                } else if status == .purchased {
                    Circle()
                        .fill(TunedUpTheme.Colors.warning)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .installed:
            return TunedUpTheme.Colors.success
        case .purchased:
            return TunedUpTheme.Colors.warning
        case .pending:
            return TunedUpTheme.Colors.textTertiary
        }
    }
}

// MARK: - Tracker DIY Badge

struct TrackerDIYBadge: View {
    let diyable: Bool
    let difficulty: Int

    private var label: String {
        if diyable {
            return "DIY \(difficulty)/5"
        } else {
            return "Pro Install"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: diyable ? "house.fill" : "wrench.and.screwdriver.fill")
                .font(.system(size: 10))

            Text(label)
                .font(TunedUpTheme.Typography.caption)
        }
        .foregroundColor(diyable ? TunedUpTheme.Colors.success : TunedUpTheme.Colors.warning)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (diyable ? TunedUpTheme.Colors.success : TunedUpTheme.Colors.warning).opacity(0.15)
        )
        .cornerRadius(TunedUpTheme.Radius.small)
    }
}

// MARK: - Loading View (reuse from elsewhere if available)

struct LoadingView: View {
    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: TunedUpTheme.Colors.cyan))
                .scaleEffect(1.5)

            Text("Loading...")
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    BuildTrackerView(build: Build(
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
    ))
}
