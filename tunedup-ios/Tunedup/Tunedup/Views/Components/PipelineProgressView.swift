import SwiftUI

// MARK: - Pipeline Progress View
// Circuit trace that lights up per step during build generation

struct PipelineProgressView: View {
    let currentStep: PipelineStep?
    let completedSteps: Set<PipelineStep>
    let failedStep: PipelineStep?

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            // Progress bar with circuit design
            GeometryReader { geometry in
                let stepWidth = geometry.size.width / CGFloat(PipelineStep.allCases.count)

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TunedUpTheme.Colors.textTertiary.opacity(0.2))
                        .frame(height: 4)

                    // Completed progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [TunedUpTheme.Colors.cyan, TunedUpTheme.Colors.magenta],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth(totalWidth: geometry.size.width), height: 4)
                        .shadow(color: TunedUpTheme.Colors.cyan.opacity(0.5), radius: 4)
                        .animation(TunedUpTheme.Animation.spring, value: completedSteps.count)

                    // Step nodes
                    ForEach(Array(PipelineStep.allCases.enumerated()), id: \.element) { index, step in
                        StepNode(
                            step: step,
                            isCompleted: completedSteps.contains(step),
                            isCurrent: currentStep == step,
                            isFailed: failedStep == step
                        )
                        .position(
                            x: stepWidth * CGFloat(index) + stepWidth / 2,
                            y: 2
                        )
                    }
                }
            }
            .frame(height: 24)

            // Current step label
            if let current = currentStep {
                HStack(spacing: TunedUpTheme.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: TunedUpTheme.Colors.cyan))
                        .scaleEffect(0.8)

                    Text(current.loadingMessage)
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                }
                .transition(.opacity)
            } else if let failed = failedStep {
                HStack(spacing: TunedUpTheme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(TunedUpTheme.Colors.error)

                    Text("Failed at: \(failed.displayName)")
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.error)
                }
            } else if completedSteps.count == PipelineStep.allCases.count {
                HStack(spacing: TunedUpTheme.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(TunedUpTheme.Colors.success)

                    Text("Build complete!")
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.success)
                }
            }
        }
        .animation(TunedUpTheme.Animation.spring, value: currentStep)
    }

    private func progressWidth(totalWidth: CGFloat) -> CGFloat {
        let stepWidth = totalWidth / CGFloat(PipelineStep.allCases.count)
        return stepWidth * CGFloat(completedSteps.count)
    }
}

// MARK: - Step Node

struct StepNode: View {
    let step: PipelineStep
    let isCompleted: Bool
    let isCurrent: Bool
    let isFailed: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer glow for current
            if isCurrent {
                Circle()
                    .fill(TunedUpTheme.Colors.cyan.opacity(isPulsing ? 0.3 : 0.1))
                    .frame(width: 24, height: 24)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
            }

            // Node circle
            Circle()
                .fill(nodeColor)
                .frame(width: 16, height: 16)

            // Checkmark or icon
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(TunedUpTheme.Colors.pureBlack)
            } else if isFailed {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            if isCurrent {
                withAnimation(
                    Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: isCurrent) { _, newValue in
            if newValue {
                withAnimation(
                    Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }

    private var nodeColor: Color {
        if isFailed {
            return TunedUpTheme.Colors.error
        } else if isCompleted {
            return TunedUpTheme.Colors.cyan
        } else if isCurrent {
            return TunedUpTheme.Colors.cyan.opacity(0.5)
        } else {
            return TunedUpTheme.Colors.textTertiary.opacity(0.3)
        }
    }
}

// MARK: - Detailed Step List

struct PipelineStepList: View {
    let currentStep: PipelineStep?
    let completedSteps: Set<PipelineStep>
    let failedStep: PipelineStep?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(PipelineStep.allCases, id: \.self) { step in
                PipelineStepRow(
                    step: step,
                    isCompleted: completedSteps.contains(step),
                    isCurrent: currentStep == step,
                    isFailed: failedStep == step,
                    isLast: step == PipelineStep.allCases.last
                )
            }
        }
    }
}

struct PipelineStepRow: View {
    let step: PipelineStep
    let isCompleted: Bool
    let isCurrent: Bool
    let isFailed: Bool
    let isLast: Bool

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: TunedUpTheme.Spacing.md) {
            // Step indicator
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(nodeColor)
                        .frame(width: 32, height: 32)

                    if isCurrent {
                        Circle()
                            .stroke(TunedUpTheme.Colors.cyan, lineWidth: 2)
                            .frame(width: 32, height: 32)
                            .scaleEffect(isPulsing ? 1.3 : 1.0)
                            .opacity(isPulsing ? 0 : 1)
                    }

                    Group {
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(TunedUpTheme.Colors.pureBlack)
                        } else if isFailed {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else if isCurrent {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.6)
                        } else {
                            Text("\(step.index + 1)")
                                .font(TunedUpTheme.Typography.caption)
                                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                        }
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? TunedUpTheme.Colors.cyan : TunedUpTheme.Colors.textTertiary.opacity(0.3))
                        .frame(width: 2, height: 24)
                }
            }

            // Step info
            VStack(alignment: .leading, spacing: 4) {
                Text(step.displayName)
                    .font(TunedUpTheme.Typography.bodyBold)
                    .foregroundColor(textColor)

                if isCurrent {
                    Text(step.loadingMessage)
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, TunedUpTheme.Spacing.sm)
        .onAppear {
            if isCurrent {
                withAnimation(
                    Animation.easeOut(duration: 1).repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
        }
    }

    private var nodeColor: Color {
        if isFailed {
            return TunedUpTheme.Colors.error
        } else if isCompleted {
            return TunedUpTheme.Colors.cyan
        } else if isCurrent {
            return TunedUpTheme.Colors.cyan
        } else {
            return TunedUpTheme.Colors.textTertiary.opacity(0.3)
        }
    }

    private var textColor: Color {
        if isFailed {
            return TunedUpTheme.Colors.error
        } else if isCompleted || isCurrent {
            return TunedUpTheme.Colors.textPrimary
        } else {
            return TunedUpTheme.Colors.textTertiary
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        TunedUpTheme.Colors.pureBlack.ignoresSafeArea()

        VStack(spacing: 48) {
            // Compact progress bar
            PipelineProgressView(
                currentStep: .synergy,
                completedSteps: [.normalize, .strategy],
                failedStep: nil
            )
            .padding(.horizontal)

            Divider()
                .background(TunedUpTheme.Colors.textTertiary)

            // Detailed step list
            PipelineStepList(
                currentStep: .synergy,
                completedSteps: [.normalize, .strategy],
                failedStep: nil
            )
            .padding(.horizontal)
        }
        .padding()
    }
}
