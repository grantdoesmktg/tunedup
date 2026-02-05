import SwiftUI

// MARK: - New Build Wizard
// One input per screen with forward motion animations

struct NewBuildWizardView: View {
    let onComplete: (String) -> Void

    @StateObject private var viewModel = WizardViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background with atmospheric depth
            TunedUpTheme.Colors.pureBlack
                .ignoresSafeArea()

            // Gradient depth layer
            LinearGradient(
                colors: [
                    TunedUpTheme.Colors.darkSurface.opacity(0.5),
                    TunedUpTheme.Colors.pureBlack,
                    TunedUpTheme.Colors.darkSurface.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Glow orbs for atmosphere
            GlowOrbBackground(
                color: TunedUpTheme.Colors.cyan,
                size: 300,
                position: CGPoint(x: 100, y: 150)
            )

            GlowOrbBackground(
                color: TunedUpTheme.Colors.magenta,
                size: 250,
                position: CGPoint(x: 300, y: 600)
            )

            // Subtle noise texture
            NoiseOverlay()
                .opacity(0.4)

            SpeedLinesBackground(lineCount: 4)

            VStack(spacing: 0) {
                // Header
                WizardHeader(
                    currentStep: viewModel.currentStep,
                    totalSteps: WizardStep.allCases.count,
                    onClose: { dismiss() }
                )

                // Progress bar
                WizardProgressBar(
                    progress: Double(viewModel.currentStep.rawValue + 1) / Double(WizardStep.allCases.count)
                )
                .padding(.horizontal, TunedUpTheme.Spacing.lg)
                .padding(.bottom, TunedUpTheme.Spacing.xl)

                // Content
                TabView(selection: $viewModel.currentStep) {
                    ForEach(WizardStep.allCases, id: \.self) { step in
                        WizardStepContent(step: step, viewModel: viewModel)
                            .tag(step)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(TunedUpTheme.Animation.spring, value: viewModel.currentStep)
                .gesture(
                    DragGesture()
                        .onEnded { _ in
                            // Dismiss keyboard on swipe
                            dismissKeyboard()
                        }
                )

                // Generate Build button (only shown on last step)
                if viewModel.currentStep == .location {
                    WizardGenerateButton(
                        canProceed: viewModel.canProceed,
                        isGenerating: viewModel.isGenerating,
                        pipelineStep: viewModel.pipelineStep,
                        onGenerate: {
                            // Dismiss keyboard
                            dismissKeyboard()

                            Task {
                                if let buildId = await viewModel.generateBuild() {
                                    onComplete(buildId)
                                }
                            }
                        }
                    )
                }
            }

            // Generating overlay
            if viewModel.isGenerating {
                GeneratingOverlay(
                    currentStep: viewModel.pipelineStep,
                    completedSteps: viewModel.completedPipelineSteps
                )
            }
        }
    }
}

// MARK: - Wizard Steps

enum WizardStep: Int, CaseIterable {
    case vehicle = 0
    case budget
    case goals
    case preferences
    case mods
    case location

    var title: String {
        switch self {
        case .vehicle: return "Your Vehicle"
        case .budget: return "Budget"
        case .goals: return "Build Goals"
        case .preferences: return "Preferences"
        case .mods: return "Existing Mods"
        case .location: return "Location"
        }
    }

    var subtitle: String {
        switch self {
        case .vehicle: return "What are we building?"
        case .budget: return "How much are you looking to spend?"
        case .goals: return "What matters most to you?"
        case .preferences: return "A few more details"
        case .mods: return "What have you already done?"
        case .location: return "For finding local shops"
        }
    }
}

// MARK: - Wizard Header

struct WizardHeader: View {
    let currentStep: WizardStep
    let totalSteps: Int
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: {
                Haptics.impact(.light)
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text("STEP \(currentStep.rawValue + 1) OF \(totalSteps)")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .tracking(2)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, TunedUpTheme.Spacing.md)
    }
}

// MARK: - Progress Bar

struct WizardProgressBar: View {
    let progress: Double

    @State private var animatedProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 2)
                    .fill(TunedUpTheme.Colors.textTertiary.opacity(0.2))

                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(TunedUpTheme.Colors.brandGradient)
                    .frame(width: geometry.size.width * animatedProgress)
                    .shadow(color: TunedUpTheme.Colors.cyan.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 4)
        .onAppear {
            withAnimation(TunedUpTheme.Animation.spring) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(TunedUpTheme.Animation.spring) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Step Content

struct WizardStepContent: View {
    let step: WizardStep
    @ObservedObject var viewModel: WizardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.xl) {
                // Title
                VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
                    Text(step.title)
                        .font(TunedUpTheme.Typography.largeTitle)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    Text(step.subtitle)
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                }

                // Step-specific content
                switch step {
                case .vehicle:
                    VehicleStepContent(viewModel: viewModel)
                case .budget:
                    BudgetStepContent(viewModel: viewModel)
                case .goals:
                    GoalsStepContent(viewModel: viewModel)
                case .preferences:
                    PreferencesStepContent(viewModel: viewModel)
                case .mods:
                    ModsStepContent(viewModel: viewModel)
                case .location:
                    LocationStepContent(viewModel: viewModel)
                }
            }
            .padding(.horizontal, TunedUpTheme.Spacing.lg)
            .padding(.top, TunedUpTheme.Spacing.lg)
            .padding(.bottom, step == .location ? 140 : 40) // Extra space for Generate button
        }
        .onTapGesture {
            // Dismiss keyboard on tap
            dismissKeyboard()
        }
        .onChange(of: viewModel.currentStep) { _, _ in
            // Dismiss keyboard when changing steps
            dismissKeyboard()
        }
    }
}

// MARK: - Vehicle Step

struct VehicleStepContent: View {
    @ObservedObject var viewModel: WizardViewModel

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            WizardTextField(
                label: "Year",
                placeholder: "2019",
                text: $viewModel.yearText,
                keyboardType: .numberPad
            )

            WizardTextField(
                label: "Make",
                placeholder: "Honda",
                text: $viewModel.make
            )

            WizardTextField(
                label: "Model",
                placeholder: "Civic",
                text: $viewModel.model
            )

            WizardTextField(
                label: "Trim",
                placeholder: "Si",
                text: $viewModel.trim
            )

            // Transmission picker
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
                Text("Transmission")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    .tracking(1)

                HStack(spacing: TunedUpTheme.Spacing.sm) {
                    TransmissionButton(
                        label: "Manual",
                        isSelected: viewModel.transmission == "manual",
                        onTap: { viewModel.transmission = "manual" }
                    )
                    TransmissionButton(
                        label: "Auto",
                        isSelected: viewModel.transmission == "auto",
                        onTap: { viewModel.transmission = "auto" }
                    )
                    TransmissionButton(
                        label: "Unknown",
                        isSelected: viewModel.transmission == "unknown",
                        onTap: { viewModel.transmission = "unknown" }
                    )
                }
            }
        }
    }
}

struct TransmissionButton: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            onTap()
        }) {
            Text(label)
                .font(TunedUpTheme.Typography.buttonSmall)
                .foregroundColor(isSelected ? TunedUpTheme.Colors.pureBlack : TunedUpTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isSelected ? TunedUpTheme.Colors.cyan : TunedUpTheme.Colors.cardSurface)
                .cornerRadius(TunedUpTheme.Radius.small)
        }
    }
}

// MARK: - Budget Step

struct BudgetStepContent: View {
    @ObservedObject var viewModel: WizardViewModel

    let presets = [2500, 5000, 10000, 15000, 25000]

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.xl) {
            // Large budget display
            VStack(spacing: TunedUpTheme.Spacing.sm) {
                Text("$\(viewModel.budget.formattedWithCommas)")
                    .font(TunedUpTheme.Typography.heroTitle)
                    .foregroundColor(TunedUpTheme.Colors.cyan)
                    .glow(color: TunedUpTheme.Colors.cyan, radius: 20)

                Text("Total Budget")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TunedUpTheme.Spacing.xl)

            // Slider
            VStack(spacing: TunedUpTheme.Spacing.md) {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.budget) },
                        set: { viewModel.budget = Int($0) }
                    ),
                    in: 1000...50000,
                    step: 500
                )
                .tint(TunedUpTheme.Colors.cyan)

                HStack {
                    Text("$1,000")
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    Spacer()
                    Text("$50,000")
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                }
            }

            // Quick presets
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
                Text("QUICK SELECT")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    .tracking(1)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: TunedUpTheme.Spacing.sm) {
                    ForEach(presets, id: \.self) { preset in
                        Button(action: {
                            Haptics.selection()
                            withAnimation(TunedUpTheme.Animation.springFast) {
                                viewModel.budget = preset
                            }
                        }) {
                            Text("$\(preset.formattedWithCommas)")
                                .font(TunedUpTheme.Typography.buttonSmall)
                                .foregroundColor(
                                    viewModel.budget == preset
                                        ? TunedUpTheme.Colors.pureBlack
                                        : TunedUpTheme.Colors.textSecondary
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(
                                    viewModel.budget == preset
                                        ? TunedUpTheme.Colors.cyan
                                        : TunedUpTheme.Colors.cardSurface
                                )
                                .cornerRadius(TunedUpTheme.Radius.small)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Goals Step

struct GoalsStepContent: View {
    @ObservedObject var viewModel: WizardViewModel

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.xl) {
            GoalSlider(
                label: "Power",
                description: "Horsepower, torque, acceleration",
                icon: "bolt.fill",
                value: $viewModel.powerGoal,
                color: TunedUpTheme.Colors.cyan
            )

            GoalSlider(
                label: "Handling",
                description: "Cornering, grip, suspension",
                icon: "arrow.triangle.swap",
                value: $viewModel.handlingGoal,
                color: TunedUpTheme.Colors.magenta
            )

            GoalSlider(
                label: "Reliability",
                description: "Longevity, daily drivability",
                icon: "shield.fill",
                value: $viewModel.reliabilityGoal,
                color: TunedUpTheme.Colors.success
            )
        }
    }
}

struct GoalSlider: View {
    let label: String
    let description: String
    let icon: String
    let value: Binding<Int>
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(TunedUpTheme.Typography.bodyBold)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    Text(description)
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textTertiary)
                }

                Spacer()

                Text("\(value.wrappedValue)")
                    .font(TunedUpTheme.Typography.dataMedium)
                    .foregroundColor(color)
            }

            // Custom segmented slider
            HStack(spacing: TunedUpTheme.Spacing.sm) {
                ForEach(1...5, id: \.self) { level in
                    Button(action: {
                        Haptics.selection()
                        withAnimation(TunedUpTheme.Animation.springFast) {
                            value.wrappedValue = level
                        }
                    }) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(level <= value.wrappedValue ? color : TunedUpTheme.Colors.cardSurface)
                            .frame(height: 8)
                    }
                }
            }
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
    }
}

// MARK: - Preferences Step

struct PreferencesStepContent: View {
    @ObservedObject var viewModel: WizardViewModel

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            PreferenceToggle(
                label: "Daily Driver",
                description: "This car is my primary transportation",
                icon: "car.fill",
                isOn: $viewModel.dailyDriver
            )

            PreferenceToggle(
                label: "Emissions Sensitive",
                description: "I need to pass smog/emissions tests",
                icon: "leaf.fill",
                isOn: $viewModel.emissionsSensitive
            )

            PreferenceToggle(
                label: "Track Car",
                description: "Built for track days and racing",
                icon: "flag.checkered",
                isOn: $viewModel.trackCar
            )

            PreferenceToggle(
                label: "Drift Build",
                description: "Optimized for drifting and sliding",
                icon: "tornado",
                isOn: $viewModel.driftBuild
            )

            PreferenceToggle(
                label: "Off Road",
                description: "Built for off-road adventures",
                icon: "mountain.2.fill",
                isOn: $viewModel.offRoad
            )
        }
    }
}

struct PreferenceToggle: View {
    let label: String
    let description: String
    let icon: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(spacing: TunedUpTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isOn.wrappedValue ? TunedUpTheme.Colors.cyan : TunedUpTheme.Colors.textTertiary)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(TunedUpTheme.Typography.bodyBold)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                Text(description)
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .tint(TunedUpTheme.Colors.cyan)
                .labelsHidden()
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
        .onTapGesture {
            Haptics.selection()
            withAnimation(TunedUpTheme.Animation.springFast) {
                isOn.wrappedValue.toggle()
            }
        }
    }
}

// MARK: - Mods Step

struct ModsStepContent: View {
    @ObservedObject var viewModel: WizardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
            Text("List any modifications you've already done:")
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)

            TextEditor(text: $viewModel.existingMods)
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textPrimary)
                .padding(TunedUpTheme.Spacing.md)
                .frame(minHeight: 150)
                .background(TunedUpTheme.Colors.cardSurface)
                .cornerRadius(TunedUpTheme.Radius.medium)
                .scrollContentBackground(.hidden)

            Text("Examples: cold air intake, lowering springs, exhaust, tune")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
        }
    }
}

// MARK: - Location Step

struct LocationStepContent: View {
    @ObservedObject var viewModel: WizardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.lg) {
            Text("This helps us suggest local shops and account for regional factors.")
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)

            WizardTextField(
                label: "City",
                placeholder: "Los Angeles, CA",
                text: $viewModel.city
            )

            // Optional marker
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)

                Text("This field is optional")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
            }
            .padding(.top, TunedUpTheme.Spacing.sm)
        }
    }
}

// MARK: - Wizard Text Field

struct WizardTextField: View {
    let label: String
    let placeholder: String
    let text: Binding<String>
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            Text(label.uppercased())
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                .tracking(1)

            TextField(placeholder, text: text)
                .font(TunedUpTheme.Typography.title2)
                .foregroundColor(TunedUpTheme.Colors.textPrimary)
                .keyboardType(keyboardType)
                .focused($isFocused)
                .padding(TunedUpTheme.Spacing.md)
                .background(TunedUpTheme.Colors.cardSurface)
                .cornerRadius(TunedUpTheme.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                        .stroke(
                            isFocused ? TunedUpTheme.Colors.cyan : Color.clear,
                            lineWidth: 2
                        )
                )
                .animation(TunedUpTheme.Animation.springFast, value: isFocused)
        }
    }
}

// MARK: - Generate Build Button with Loading State

struct WizardGenerateButton: View {
    let canProceed: Bool
    let isGenerating: Bool
    let pipelineStep: PipelineStep?
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(TunedUpTheme.Colors.textTertiary.opacity(0.2))

            VStack(spacing: TunedUpTheme.Spacing.md) {
                // Status text while generating
                if isGenerating, let step = pipelineStep {
                    HStack(spacing: TunedUpTheme.Spacing.sm) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: TunedUpTheme.Colors.cyan))
                            .scaleEffect(0.8)

                        Text(step.loadingMessage)
                            .font(TunedUpTheme.Typography.callout)
                            .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    }
                    .padding(.top, TunedUpTheme.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Generate button
                Button(action: {
                    Haptics.impact(.medium)
                    onGenerate()
                }) {
                    HStack(spacing: TunedUpTheme.Spacing.sm) {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: TunedUpTheme.Colors.pureBlack))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "sparkles")
                        }

                        Text(isGenerating ? "Generating..." : "Generate Build")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canProceed || isGenerating)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, TunedUpTheme.Spacing.lg)
                .animation(TunedUpTheme.Animation.spring, value: isGenerating)
            }
            .padding(.vertical, TunedUpTheme.Spacing.md)
            .background(
                TunedUpTheme.Colors.pureBlack
                    .overlay(
                        // Subtle glow when generating
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        TunedUpTheme.Colors.cyan.opacity(isGenerating ? 0.1 : 0),
                                        TunedUpTheme.Colors.pureBlack
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .allowsHitTesting(false)
                    )
            )
        }
        .animation(TunedUpTheme.Animation.spring, value: isGenerating)
    }
}

// MARK: - Generating Overlay

struct GeneratingOverlay: View {
    let currentStep: PipelineStep?
    let completedSteps: Set<PipelineStep>

    var body: some View {
        ZStack {
            // Atmospheric background
            TunedUpTheme.Colors.pureBlack
                .ignoresSafeArea()

            // Depth gradient
            LinearGradient(
                colors: [
                    TunedUpTheme.Colors.darkSurface.opacity(0.8),
                    TunedUpTheme.Colors.pureBlack,
                    TunedUpTheme.Colors.darkSurface.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Atmospheric glow orbs
            GlowOrbBackground(
                color: TunedUpTheme.Colors.cyan,
                size: 400,
                position: CGPoint(x: 200, y: 250)
            )

            GlowOrbBackground(
                color: TunedUpTheme.Colors.magenta,
                size: 350,
                position: CGPoint(x: 250, y: 650)
            )

            // Subtle noise
            NoiseOverlay()
                .opacity(0.3)

            // Speed lines for energy
            SpeedLinesBackground(lineCount: 6, isAnimating: true)
                .opacity(0.6)

            VStack(spacing: TunedUpTheme.Spacing.xxl) {
                // Animated logo/icon
                ZStack {
                    Circle()
                        .fill(TunedUpTheme.Colors.cyan.opacity(0.1))
                        .frame(width: 120, height: 120)

                    CircuitTraceBackground(isAnimating: true)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())

                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 40))
                        .foregroundColor(TunedUpTheme.Colors.cyan)
                }

                VStack(spacing: TunedUpTheme.Spacing.sm) {
                    Text("Building Your Plan")
                        .font(TunedUpTheme.Typography.title1)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    if let step = currentStep {
                        Text(step.loadingMessage)
                            .font(TunedUpTheme.Typography.body)
                            .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    }
                }

                // Step progress
                PipelineStepList(
                    currentStep: currentStep,
                    completedSteps: completedSteps,
                    failedStep: nil
                )
                .padding(.horizontal, TunedUpTheme.Spacing.xl)
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Preview

#Preview {
    NewBuildWizardView(onComplete: { _ in })
}
