import SwiftUI

// MARK: - New Build Wizard
// One input per screen with forward motion animations

struct NewBuildWizardView: View {
    let onComplete: (String) -> Void

    @StateObject private var viewModel = WizardViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background
            TunedUpTheme.Colors.pureBlack
                .ignoresSafeArea()

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

                // Bottom buttons
                WizardBottomButtons(
                    currentStep: viewModel.currentStep,
                    canProceed: viewModel.canProceed,
                    isGenerating: viewModel.isGenerating,
                    onBack: { viewModel.goBack() },
                    onNext: { viewModel.goNext() },
                    onGenerate: {
                        Task {
                            if let buildId = await viewModel.generateBuild() {
                                onComplete(buildId)
                            }
                        }
                    }
                )
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
            .padding(.bottom, 120) // Space for bottom buttons
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

// MARK: - Bottom Buttons

struct WizardBottomButtons: View {
    let currentStep: WizardStep
    let canProceed: Bool
    let isGenerating: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onGenerate: () -> Void

    private var isFirstStep: Bool {
        currentStep == WizardStep.allCases.first
    }

    private var isLastStep: Bool {
        currentStep == WizardStep.allCases.last
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(TunedUpTheme.Colors.textTertiary.opacity(0.2))

            HStack(spacing: TunedUpTheme.Spacing.md) {
                // Back button
                if !isFirstStep {
                    Button(action: {
                        Haptics.impact(.light)
                        onBack()
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                }

                Spacer()

                // Next/Generate button
                if isLastStep {
                    Button(action: {
                        Haptics.impact(.medium)
                        onGenerate()
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Build")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(width: 200)
                    .disabled(!canProceed || isGenerating)
                } else {
                    Button(action: {
                        Haptics.impact(.light)
                        onNext()
                    }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(width: 120)
                    .disabled(!canProceed)
                }
            }
            .padding(.horizontal, TunedUpTheme.Spacing.lg)
            .padding(.vertical, TunedUpTheme.Spacing.md)
            .background(TunedUpTheme.Colors.pureBlack)
        }
    }
}

// MARK: - Generating Overlay

struct GeneratingOverlay: View {
    let currentStep: PipelineStep?
    let completedSteps: Set<PipelineStep>

    var body: some View {
        ZStack {
            TunedUpTheme.Colors.pureBlack.opacity(0.95)
                .ignoresSafeArea()

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
