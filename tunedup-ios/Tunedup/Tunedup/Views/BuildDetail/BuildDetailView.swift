import SwiftUI

// MARK: - Build Detail View
// Horizontal scrolling stages with full stats display

struct BuildDetailView: View {
    let buildId: String

    @StateObject private var viewModel = BuildDetailViewModel()
    @State private var selectedStage: Int = 0
    @State private var showingChat = false
    @State private var showingDeleteConfirm = false
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            TunedUpTheme.Colors.pureBlack
                .ignoresSafeArea()

            if viewModel.isLoading {
                LoadingView()
            } else if let build = viewModel.build {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with vehicle info
                        BuildDetailHeader(
                            build: build,
                            isDeleting: isDeleting,
                            onBack: { dismiss() },
                            onDelete: { showingDeleteConfirm = true }
                        )

                        // Performance stats
                        if let performance = build.performance {
                            PerformanceSection(
                                performance: performance,
                                selectedStage: selectedStage
                            )
                            .padding(.horizontal, TunedUpTheme.Spacing.lg)
                            .padding(.bottom, TunedUpTheme.Spacing.xl)
                        }

                        // Stage selector
                        if let plan = build.plan {
                            StageSelectorStrip(
                                stages: plan.stages,
                                selectedStage: $selectedStage
                            )

                            // Stage content
                            StageDetailView(
                                stage: plan.stages[safe: selectedStage],
                                execution: build.execution,
                                sourcing: build.sourcing
                            )
                            .padding(.horizontal, TunedUpTheme.Spacing.lg)
                            .id(selectedStage) // Force refresh on stage change
                        }

                        // Assumptions & Disclaimer
                        if let assumptions = build.assumptions, !assumptions.isEmpty {
                            AssumptionsSection(assumptions: assumptions)
                                .padding(.horizontal, TunedUpTheme.Spacing.lg)
                                .padding(.top, TunedUpTheme.Spacing.xl)
                        }

                        // Bottom spacer for chat button
                        Color.clear.frame(height: 100)
                    }
                }

                // Floating chat button
                VStack {
                    Spacer()
                    ChatFloatingButton(onTap: { showingChat = true })
                }
            } else if let error = viewModel.error {
                ErrorView(message: error, onRetry: {
                    Task { await viewModel.fetchBuild(buildId) }
                })
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.fetchBuild(buildId)
        }
        .sheet(isPresented: $showingChat) {
            MechanicChatView(buildId: buildId)
        }
        .alert("Delete Build?", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    isDeleting = true
                    let success = await viewModel.deleteBuild()
                    isDeleting = false
                    if success {
                        NotificationCenter.default.post(name: .buildDeleted, object: buildId)
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This cannot be undone.")
        }
    }
}

// MARK: - Build Detail Header

struct BuildDetailHeader: View {
    let build: Build
    let isDeleting: Bool
    let onBack: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // Background gradient
            LinearGradient(
                colors: [
                    TunedUpTheme.Colors.cyan.opacity(0.15),
                    TunedUpTheme.Colors.pureBlack
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            VStack(spacing: TunedUpTheme.Spacing.lg) {
                // Nav bar
                HStack {
                    Button(action: {
                        Haptics.impact(.light)
                        onBack()
                    }) {
                        HStack(spacing: TunedUpTheme.Spacing.xs) {
                            Image(systemName: "chevron.left")
                            Text("Garage")
                        }
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    }

                    Spacer()

                    // Delete button
                    Button(action: {
                        Haptics.impact(.light)
                        onDelete()
                    }) {
                        Image(systemName: isDeleting ? "hourglass" : "trash")
                            .font(.system(size: 18))
                            .foregroundColor(TunedUpTheme.Colors.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(isDeleting)
                }
                .padding(.horizontal, TunedUpTheme.Spacing.lg)
                .padding(.top, TunedUpTheme.Spacing.md)

                // Vehicle name
                VStack(spacing: TunedUpTheme.Spacing.xs) {
                    Text("\(String(build.vehicle.year)) \(build.vehicle.make)")
                        .font(TunedUpTheme.Typography.subheadline)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)

                    Text("\(build.vehicle.model) \(build.vehicle.trim)")
                        .font(TunedUpTheme.Typography.largeTitle)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    // Archetype badge
                    if let strategy = build.strategy {
                        Text(strategy.archetype)
                            .font(TunedUpTheme.Typography.caption)
                            .foregroundColor(TunedUpTheme.Colors.cyan)
                            .padding(.horizontal, TunedUpTheme.Spacing.sm)
                            .padding(.vertical, TunedUpTheme.Spacing.xs)
                            .background(TunedUpTheme.Colors.cyan.opacity(0.15))
                            .cornerRadius(TunedUpTheme.Radius.small)
                    }
                }
            }
        }
    }
}

// MARK: - Performance Section

struct PerformanceSection: View {
    let performance: PerformanceEstimate
    let selectedStage: Int

    private var orderedStages: [Int] {
        performance.afterStage.keys.compactMap(Int.init).sorted()
    }

    private struct CumulativePerf {
        let estimatedHp: Int?
        let torque: Int?
        let zeroToSixty: DoubleRange?
        let quarterMileTime: DoubleRange?
    }

    private func cumulativePerf(upTo stage: Int) -> CumulativePerf {
        var bestHp: ValueRange?
        var torqueGainSum = 0
        var bestZeroLow: Double?
        var bestZeroHigh: Double?
        var bestQuarterLow: Double?
        var bestQuarterHigh: Double?

        for s in orderedStages where s <= stage {
            guard let perf = performance.afterStage["\(s)"] else { continue }

            // Horsepower: keep the best (highest) estimate so stages are cumulative
            if let current = bestHp {
                if perf.estimatedHp.midpoint > current.midpoint {
                    bestHp = perf.estimatedHp
                }
            } else {
                bestHp = perf.estimatedHp
            }

            // Torque: sum stage gains so it never drops
            torqueGainSum += perf.torqueGain.midpoint

            // 0-60: take the best (lowest) range
            if let low = bestZeroLow, let high = bestZeroHigh {
                bestZeroLow = min(low, perf.zeroToSixty.low)
                bestZeroHigh = min(high, perf.zeroToSixty.high)
            } else {
                bestZeroLow = perf.zeroToSixty.low
                bestZeroHigh = perf.zeroToSixty.high
            }

            // 1/4 mile: take the best (lowest) time range
            if let low = bestQuarterLow, let high = bestQuarterHigh {
                bestQuarterLow = min(low, perf.quarterMile.time.low)
                bestQuarterHigh = min(high, perf.quarterMile.time.high)
            } else {
                bestQuarterLow = perf.quarterMile.time.low
                bestQuarterHigh = perf.quarterMile.time.high
            }
        }

        let zeroRange = (bestZeroLow != nil && bestZeroHigh != nil)
            ? DoubleRange(low: bestZeroLow!, high: bestZeroHigh!)
            : nil

        let quarterRange = (bestQuarterLow != nil && bestQuarterHigh != nil)
            ? DoubleRange(low: bestQuarterLow!, high: bestQuarterHigh!)
            : nil

        let estimatedHp = bestHp?.midpoint
        let torque = performance.baseline.torque + torqueGainSum

        return CumulativePerf(
            estimatedHp: estimatedHp,
            torque: torqueGainSum == 0 ? nil : torque,
            zeroToSixty: zeroRange,
            quarterMileTime: quarterRange
        )
    }

    var body: some View {
        let cumulative = cumulativePerf(upTo: selectedStage)
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            // Main gauges
            HStack(spacing: TunedUpTheme.Spacing.xl) {
                if let estimatedHp = cumulative.estimatedHp {
                    StatGauge(
                        title: "Horsepower",
                        beforeValue: performance.baseline.hp,
                        afterValue: estimatedHp,
                        unit: "HP",
                        color: TunedUpTheme.Colors.cyan
                    )

                    StatGauge(
                        title: "Torque",
                        beforeValue: performance.baseline.torque,
                        afterValue: cumulative.torque ?? performance.baseline.torque,
                        unit: "LB-FT",
                        color: TunedUpTheme.Colors.magenta
                    )
                } else {
                    StatGauge(
                        title: "Horsepower",
                        beforeValue: performance.baseline.hp,
                        afterValue: performance.baseline.hp,
                        unit: "HP",
                        color: TunedUpTheme.Colors.cyan
                    )

                    StatGauge(
                        title: "Torque",
                        beforeValue: performance.baseline.torque,
                        afterValue: performance.baseline.torque,
                        unit: "LB-FT",
                        color: TunedUpTheme.Colors.magenta
                    )
                }
            }
            .id(selectedStage) // Force re-create gauges on stage change for animation

            // 0-60 and 1/4 mile
            HStack(spacing: TunedUpTheme.Spacing.md) {
                if let zeroRange = cumulative.zeroToSixty,
                   let quarterRange = cumulative.quarterMileTime {
                    BeforeAfterStat(
                        label: "0-60 MPH",
                        before: "\(performance.baseline.zeroToSixty.formattedOneDecimal)s",
                        after: zeroRange.formatted,
                        improvement: "-\((performance.baseline.zeroToSixty - zeroRange.low).formattedOneDecimal)s"
                    )

                    BeforeAfterStat(
                        label: "1/4 Mile",
                        before: "\(performance.baseline.quarterMile.time.formattedOneDecimal)s",
                        after: quarterRange.formatted,
                        improvement: "-\((performance.baseline.quarterMile.time - quarterRange.low).formattedOneDecimal)s"
                    )
                }
            }
        }
    }
}

// MARK: - Stage Selector Strip

struct StageSelectorStrip: View {
    let stages: [Stage]
    @Binding var selectedStage: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TunedUpTheme.Spacing.sm) {
                    ForEach(stages) { stage in
                        StageTab(
                            stage: stage,
                            isSelected: selectedStage == stage.stageNumber,
                            onTap: {
                                Haptics.selection()
                                withAnimation(TunedUpTheme.Animation.spring) {
                                    selectedStage = stage.stageNumber
                                }
                            }
                        )
                        .id(stage.stageNumber)
                    }
                }
                .padding(.horizontal, TunedUpTheme.Spacing.lg)
                .padding(.vertical, TunedUpTheme.Spacing.md)
            }
            .background(TunedUpTheme.Colors.darkSurface)
            .onChange(of: selectedStage) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

struct StageTab: View {
    let stage: Stage
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: TunedUpTheme.Spacing.xs) {
                Text("STAGE \(stage.stageNumber)")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(
                        isSelected ? TunedUpTheme.Colors.cyan : TunedUpTheme.Colors.textTertiary
                    )
                    .tracking(1)

                Text(stage.name)
                    .font(TunedUpTheme.Typography.bodyBold)
                    .foregroundColor(
                        isSelected ? TunedUpTheme.Colors.textPrimary : TunedUpTheme.Colors.textSecondary
                    )

                Text(stage.estimatedCost.formatted)
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
            }
            .padding(.horizontal, TunedUpTheme.Spacing.md)
            .padding(.vertical, TunedUpTheme.Spacing.sm)
            .background(
                isSelected ? TunedUpTheme.Colors.cyan.opacity(0.1) : Color.clear
            )
            .cornerRadius(TunedUpTheme.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                    .stroke(
                        isSelected ? TunedUpTheme.Colors.cyan : Color.clear,
                        lineWidth: 1
                    )
            )
        }
    }
}

// MARK: - Stage Detail View

struct StageDetailView: View {
    let stage: Stage?
    let execution: ExecutionPlan?
    let sourcing: Sourcing?

    var body: some View {
        if let stage = stage {
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.lg) {
                // Stage description
                Text(stage.description)
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .padding(.top, TunedUpTheme.Spacing.md)

                // Synergy groups
                ForEach(stage.synergyGroups) { group in
                    SynergyIndicator(
                        synergyGroup: group,
                        isExpanded: true
                    )
                }

                // Mods list
                VStack(spacing: TunedUpTheme.Spacing.md) {
                    ForEach(stage.mods) { mod in
                        ModDetailCard(
                            mod: mod,
                            execution: execution?.modExecutions.first { $0.modId == mod.id },
                            sourcing: sourcing?.modSourcing.first { $0.modId == mod.id },
                            synergyCount: stage.synergyGroups.filter { $0.modIds.contains(mod.id) }.count
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Mod Detail Card

struct ModDetailCard: View {
    let mod: Mod
    let execution: ModExecution?
    let sourcing: ModSourcing?
    let synergyCount: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible)
            Button(action: {
                Haptics.selection()
                withAnimation(TunedUpTheme.Animation.spring) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.xs) {
                        HStack(spacing: 6) {
                            Text(mod.name)
                                .font(TunedUpTheme.Typography.bodyBold)
                                .foregroundColor(TunedUpTheme.Colors.textPrimary)

                            if let exec = execution, !exec.diyable {
                                Image(systemName: "wrench.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(TunedUpTheme.Colors.warning)
                            }

                            if synergyCount > 0 {
                                ModSynergyBadge(count: synergyCount)
                            }
                        }

                        Text(mod.category.capitalized)
                            .font(TunedUpTheme.Typography.caption)
                            .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: TunedUpTheme.Spacing.xs) {
                        Text(mod.estimatedCost.formatted)
                            .font(TunedUpTheme.Typography.dataCaption)
                            .foregroundColor(TunedUpTheme.Colors.cyan)

                        if let exec = execution {
                            DIYBadge(diyable: exec.diyable, difficulty: exec.difficulty)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                        .padding(.leading, TunedUpTheme.Spacing.sm)
                }
                .padding(TunedUpTheme.Spacing.md)
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
                    Divider()
                        .background(TunedUpTheme.Colors.textTertiary.opacity(0.2))

                    // Description
                    Text(mod.description)
                        .font(TunedUpTheme.Typography.footnote)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)

                    // Justification
                    HStack(alignment: .top, spacing: TunedUpTheme.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 14))
                            .foregroundColor(TunedUpTheme.Colors.warning)

                        Text(mod.justification)
                            .font(TunedUpTheme.Typography.footnote)
                            .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    }

                    // Execution details
                    if let exec = execution {
                        ExecutionDetails(execution: exec)
                    }

                    // Sourcing
                    if let src = sourcing {
                        SourcingDetails(sourcing: src)
                    }
                }
                .padding(.horizontal, TunedUpTheme.Spacing.md)
                .padding(.bottom, TunedUpTheme.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
    }
}

struct DIYBadge: View {
    let diyable: Bool
    let difficulty: Int

    private var label: String {
        if diyable {
            return "Garage DIY \(difficulty)/5"
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

struct ExecutionDetails: View {
    let execution: ModExecution

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            Text("INSTALLATION")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .tracking(1)

            HStack(spacing: TunedUpTheme.Spacing.lg) {
                // Time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(execution.timeEstimate.hours.formatted)
                        .font(TunedUpTheme.Typography.caption)
                }
                .foregroundColor(TunedUpTheme.Colors.textSecondary)

                // Difficulty
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { level in
                        Circle()
                            .fill(
                                level <= execution.difficulty
                                    ? TunedUpTheme.Colors.cyan
                                    : TunedUpTheme.Colors.textTertiary.opacity(0.3)
                            )
                            .frame(width: 8, height: 8)
                    }
                }

                // Labor cost if shop
                if let labor = execution.shopLaborEstimate {
                    Text("Labor: \(labor.formatted)")
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                }
            }

            // Risk notes
            if !execution.riskNotes.isEmpty {
                HStack(alignment: .top, spacing: TunedUpTheme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundColor(TunedUpTheme.Colors.warning)

                    Text(execution.riskNotes.joined(separator: ". "))
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.warning)
                }
            }
        }
        .padding(TunedUpTheme.Spacing.sm)
        .background(TunedUpTheme.Colors.darkSurface)
        .cornerRadius(TunedUpTheme.Radius.small)
    }
}

struct SourcingDetails: View {
    let sourcing: ModSourcing

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            Text("PARTS")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .tracking(1)

            // Brand links
            FlowLayout(spacing: TunedUpTheme.Spacing.sm) {
                ForEach(Array(zip(sourcing.reputableBrands, sourcing.searchQueries.prefix(sourcing.reputableBrands.count))), id: \.0) { brand, query in
                    BrandLink(brand: brand, searchQuery: query)
                }
                // Extra search queries without a matching brand name
                ForEach(Array(sourcing.searchQueries.dropFirst(sourcing.reputableBrands.count)), id: \.self) { query in
                    BrandLink(brand: query, searchQuery: query)
                }
            }
        }
        .padding(TunedUpTheme.Spacing.sm)
        .background(TunedUpTheme.Colors.darkSurface)
        .cornerRadius(TunedUpTheme.Radius.small)
    }
}

struct BrandLink: View {
    let brand: String
    let searchQuery: String

    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            if let url = URL(string: "https://www.google.com/search?q=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 4) {
                Text(brand)
                    .font(TunedUpTheme.Typography.caption)
                    .fontWeight(.medium)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(TunedUpTheme.Colors.cyan)
            .padding(.horizontal, TunedUpTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(TunedUpTheme.Colors.cyan.opacity(0.1))
            .cornerRadius(TunedUpTheme.Radius.small)
            .overlay(
                RoundedRectangle(cornerRadius: TunedUpTheme.Radius.small)
                    .stroke(TunedUpTheme.Colors.cyan.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

// Simple flow layout that wraps items to the next line
struct FlowLayout: Layout {
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

// MARK: - Assumptions Section

struct AssumptionsSection: View {
    let assumptions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
                Text("Assumptions & Disclaimer")
                    .font(TunedUpTheme.Typography.bodyBold)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
            }

            ForEach(assumptions, id: \.self) { assumption in
                HStack(alignment: .top, spacing: TunedUpTheme.Spacing.sm) {
                    Text("•")
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    Text(assumption)
                        .font(TunedUpTheme.Typography.footnote)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                }
            }

            Text("Estimates are approximate and depend on tune quality, installation, fuel, altitude, and driver skill. Always consult a professional before making modifications.")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .italic()
                .padding(.top, TunedUpTheme.Spacing.sm)
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
    }
}

// MARK: - Chat Floating Button

struct ChatFloatingButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.impact(.medium)
            onTap()
        }) {
            HStack(spacing: TunedUpTheme.Spacing.sm) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 20))
                Text("Ask Mechanic")
                    .font(TunedUpTheme.Typography.button)
            }
            .foregroundColor(TunedUpTheme.Colors.pureBlack)
            .padding(.horizontal, TunedUpTheme.Spacing.lg)
            .padding(.vertical, TunedUpTheme.Spacing.md)
            .background(TunedUpTheme.Colors.cyan)
            .cornerRadius(TunedUpTheme.Radius.pill)
            .shadow(color: TunedUpTheme.Colors.cyan.opacity(0.4), radius: 12, y: 4)
        }
        .padding(.bottom, TunedUpTheme.Spacing.xl)
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(TunedUpTheme.Colors.error)

            Text("Something went wrong")
                .font(TunedUpTheme.Typography.title2)
                .foregroundColor(TunedUpTheme.Colors.textPrimary)

            Text(message)
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

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
    BuildDetailView(buildId: "test-id")
}
