import SwiftUI

// MARK: - Garage View
// Main screen showing up to 3 builds with 3D tilted card carousel

struct GarageView: View {
    @StateObject private var viewModel = GarageViewModel()
    @State private var selectedIndex: Int = 0
    @State private var showingWizard = false
    @State private var selectedBuildId: String?
    @State private var showingLimitAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TunedUpTheme.Colors.pureBlack
                    .ignoresSafeArea()

                SpeedLinesBackground(lineCount: 6)

                // Glow orbs
                GlowOrbBackground(
                    color: TunedUpTheme.Colors.cyan,
                    size: 400,
                    position: CGPoint(x: UIScreen.main.bounds.width - 50, y: 150)
                )

                GlowOrbBackground(
                    color: TunedUpTheme.Colors.magenta,
                    size: 300,
                    position: CGPoint(x: 50, y: UIScreen.main.bounds.height - 200)
                )

                // Content
                VStack(spacing: 0) {
                    // Header
                    GarageHeader(buildCount: viewModel.builds.count)

                    if viewModel.isLoading && viewModel.builds.isEmpty {
                        // Loading state
                        Spacer()
                        LoadingView()
                        Spacer()
                    } else if viewModel.builds.isEmpty && !viewModel.isLoading {
                        // Empty state
                        Spacer()
                        EmptyGarageView(onCreateTap: { showingWizard = true })
                        Spacer()
                    } else {
                        // Build cards carousel
                        Spacer()

                        BuildCarousel(
                            builds: viewModel.builds,
                            canCreateNew: viewModel.canCreateNew,
                            selectedIndex: $selectedIndex,
                            onBuildTap: { build in
                                selectedBuildId = build.id
                            },
                            onNewBuildTap: {
                                if viewModel.canCreateNew {
                                    showingWizard = true
                                } else {
                                    showingLimitAlert = true
                                }
                            }
                        )

                        Spacer()

                        // Bottom action area
                        BottomActionArea(
                            selectedBuild: viewModel.builds[safe: selectedIndex],
                            onChatTap: {
                                // Navigate to chat
                            },
                            onDetailsTap: {
                                if let build = viewModel.builds[safe: selectedIndex] {
                                    selectedBuildId = build.id
                                }
                            }
                        )
                    }
                }
                .padding(.top, TunedUpTheme.Spacing.md)
            }
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.fetchBuilds()
            }
            .task {
                await viewModel.fetchBuilds()
            }
            .onReceive(NotificationCenter.default.publisher(for: .buildDeleted)) { _ in
                Task { await viewModel.fetchBuilds() }
            }
            .onChange(of: viewModel.builds.count) { _, newCount in
                if newCount == 0 {
                    selectedIndex = 0
                } else {
                    let maxIndex = newCount // includes add card
                    selectedIndex = min(selectedIndex, max(0, maxIndex))
                }
            }
            .fullScreenCover(isPresented: $showingWizard) {
                NewBuildWizardView(onComplete: { buildId in
                    showingWizard = false
                    selectedBuildId = buildId
                    Task {
                        await viewModel.fetchBuilds()
                    }
                })
            }
            .navigationDestination(item: $selectedBuildId) { buildId in
                BuildDetailView(buildId: buildId)
            }
            .alert("Build limit reached", isPresented: $showingLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can save up to 3 builds. Delete one to create a new build.")
            }
        }
    }
}

// MARK: - Garage Header

struct GarageHeader: View {
    let buildCount: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.xs) {
                Text("MY GARAGE")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    .tracking(2)

                Text("\(buildCount)/3 Builds")
                    .font(TunedUpTheme.Typography.title1)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)
            }

            Spacer()

            // Settings button
            Button(action: {
                Haptics.impact(.light)
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 22))
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(TunedUpTheme.Colors.cardSurface)
                    .cornerRadius(TunedUpTheme.Radius.medium)
            }
        }
        .padding(.horizontal, TunedUpTheme.Spacing.lg)
        .padding(.bottom, TunedUpTheme.Spacing.md)
    }
}

// MARK: - Build Carousel

struct BuildCarousel: View {
    let builds: [BuildSummary]
    let canCreateNew: Bool
    let selectedIndex: Binding<Int>
    let onBuildTap: (BuildSummary) -> Void
    let onNewBuildTap: () -> Void

    @GestureState private var dragOffset: CGFloat = 0

    private let cardWidth: CGFloat = UIScreen.main.bounds.width - 80
    private let cardSpacing: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let totalItems = builds.count + 1

            HStack(spacing: cardSpacing) {
                // Existing builds
                ForEach(Array(builds.enumerated()), id: \.element.id) { index, build in
                    BuildCard(
                        build: build,
                        isSelected: selectedIndex.wrappedValue == index,
                        onTap: {
                            if selectedIndex.wrappedValue == index {
                                onBuildTap(build)
                            } else {
                                withAnimation(TunedUpTheme.Animation.spring) {
                                    selectedIndex.wrappedValue = index
                                }
                            }
                        }
                    )
                    .frame(width: cardWidth)
                    .rotation3DEffect(
                        rotationAngle(for: index, selected: selectedIndex.wrappedValue),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .scaleEffect(scaleEffect(for: index, selected: selectedIndex.wrappedValue))
                    .opacity(opacityEffect(for: index, selected: selectedIndex.wrappedValue))
                }

                // New build card
                EmptyBuildCard(isEnabled: canCreateNew, onTap: {
                    if selectedIndex.wrappedValue == builds.count {
                        onNewBuildTap()
                    } else {
                        withAnimation(TunedUpTheme.Animation.spring) {
                            selectedIndex.wrappedValue = builds.count
                        }
                    }
                })
                    .frame(width: cardWidth)
                    .rotation3DEffect(
                        rotationAngle(for: builds.count, selected: selectedIndex.wrappedValue),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .scaleEffect(scaleEffect(for: builds.count, selected: selectedIndex.wrappedValue))
                    .opacity(opacityEffect(for: builds.count, selected: selectedIndex.wrappedValue))
            }
            .padding(.horizontal, (geometry.size.width - cardWidth) / 2)
            .offset(x: -CGFloat(selectedIndex.wrappedValue) * (cardWidth + cardSpacing) + dragOffset)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        var newIndex = selectedIndex.wrappedValue

                        if value.translation.width < -threshold {
                            newIndex = min(selectedIndex.wrappedValue + 1, totalItems - 1)
                        } else if value.translation.width > threshold {
                            newIndex = max(selectedIndex.wrappedValue - 1, 0)
                        }

                        withAnimation(TunedUpTheme.Animation.spring) {
                            selectedIndex.wrappedValue = newIndex
                        }
                        Haptics.selection()
                    }
            )
            .animation(TunedUpTheme.Animation.spring, value: dragOffset)
        }
        .frame(height: 260)
    }

    private func rotationAngle(for index: Int, selected: Int) -> Angle {
        let diff = index - selected
        if diff == 0 { return .degrees(0) }
        return .degrees(Double(diff) * -8)
    }

    private func scaleEffect(for index: Int, selected: Int) -> CGFloat {
        let diff = abs(index - selected)
        if diff == 0 { return 1.0 }
        return max(0.85, 1.0 - CGFloat(diff) * 0.1)
    }

    private func opacityEffect(for index: Int, selected: Int) -> Double {
        let diff = abs(index - selected)
        if diff == 0 { return 1.0 }
        return max(0.5, 1.0 - Double(diff) * 0.3)
    }
}

// MARK: - Bottom Action Area

struct BottomActionArea: View {
    let selectedBuild: BuildSummary?
    let onChatTap: () -> Void
    let onDetailsTap: () -> Void

    var body: some View {
        if let build = selectedBuild, build.pipelineStatus == .completed {
            VStack(spacing: TunedUpTheme.Spacing.md) {
                // Quick stats
                if let stats = build.statsPreview {
                    HStack(spacing: TunedUpTheme.Spacing.xl) {
                        if let hp = stats.hpGainRange, hp.count == 2 {
                            QuickStat(
                                icon: "bolt.fill",
                                value: "+\(hp[0])-\(hp[1])",
                                label: "HP Gain",
                                color: TunedUpTheme.Colors.cyan
                            )
                        }

                        QuickStat(
                            icon: "dollarsign.circle",
                            value: "$\(stats.totalBudget.formattedWithCommas)",
                            label: "Budget",
                            color: TunedUpTheme.Colors.magenta
                        )
                    }
                }

                // Action buttons
                HStack(spacing: TunedUpTheme.Spacing.md) {
                    Button(action: {
                        Haptics.impact(.medium)
                        onDetailsTap()
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("View Build")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: {
                        Haptics.impact(.medium)
                        onChatTap()
                    }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("Ask Mechanic")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.horizontal, TunedUpTheme.Spacing.lg)
            .padding(.bottom, TunedUpTheme.Spacing.xl)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Empty Garage View

struct EmptyGarageView: View {
    let onCreateTap: () -> Void

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.xl) {
            // Icon
            ZStack {
                Circle()
                    .fill(TunedUpTheme.Colors.cyan.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "car.side")
                    .font(.system(size: 48))
                    .foregroundColor(TunedUpTheme.Colors.cyan)
            }

            // Text
            VStack(spacing: TunedUpTheme.Spacing.sm) {
                Text("Your garage is empty")
                    .font(TunedUpTheme.Typography.title2)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                Text("Create your first build to get started")
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // CTA
            Button(action: {
                Haptics.impact(.medium)
                onCreateTap()
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Build")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(width: 200)
        }
        .padding(TunedUpTheme.Spacing.xl)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .stroke(TunedUpTheme.Colors.textTertiary.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(TunedUpTheme.Colors.cyan, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }

            Text("Loading garage...")
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 1).repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    GarageView()
}
