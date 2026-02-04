import Foundation
import SwiftUI
import Combine

@MainActor
class WizardViewModel: ObservableObject {
    // MARK: - Navigation
    @Published var currentStep: WizardStep = .vehicle

    // MARK: - Vehicle inputs
    @Published var yearText: String = ""
    @Published var make: String = ""
    @Published var model: String = ""
    @Published var trim: String = ""
    @Published var transmission: String = "unknown"

    // MARK: - Budget
    @Published var budget: Int = 5000

    // MARK: - Goals (1-5)
    @Published var powerGoal: Int = 3
    @Published var handlingGoal: Int = 3
    @Published var reliabilityGoal: Int = 3

    // MARK: - Preferences
    @Published var dailyDriver: Bool = true
    @Published var emissionsSensitive: Bool = false

    // MARK: - Existing mods
    @Published var existingMods: String = ""

    // MARK: - Location
    @Published var city: String = ""

    // MARK: - Generation state
    @Published var isGenerating: Bool = false
    @Published var pipelineStep: PipelineStep?
    @Published var completedPipelineSteps: Set<PipelineStep> = []
    @Published var error: String?

    private let sseClient = SSEClient()

    // MARK: - Computed Properties

    var year: Int {
        Int(yearText) ?? 0
    }

    var canProceed: Bool {
        switch currentStep {
        case .vehicle:
            return !yearText.isEmpty && !make.isEmpty && !model.isEmpty && !trim.isEmpty
        case .budget:
            return budget >= 1000
        case .goals:
            return true
        case .preferences:
            return true
        case .mods:
            return true
        case .location:
            return true
        }
    }

    // MARK: - Navigation

    func goNext() {
        guard canProceed else { return }
        let allSteps = WizardStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex < allSteps.count - 1 {
            withAnimation(TunedUpTheme.Animation.spring) {
                currentStep = allSteps[currentIndex + 1]
            }
        }
    }

    func goBack() {
        let allSteps = WizardStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep),
           currentIndex > 0 {
            withAnimation(TunedUpTheme.Animation.spring) {
                currentStep = allSteps[currentIndex - 1]
            }
        }
    }

    // MARK: - Build Generation

    func generateBuild() async -> String? {
        guard canProceed else { return nil }

        isGenerating = true
        pipelineStep = nil
        completedPipelineSteps = []
        error = nil

        let vehicleInput = VehicleInput(
            year: year,
            make: make,
            model: model,
            trim: trim,
            engine: nil,
            drivetrain: nil,
            fuel: nil,
            transmission: transmission
        )

        let intentInput = IntentInput(
            budget: budget,
            goals: GoalSliders(
                power: powerGoal,
                handling: handlingGoal,
                reliability: reliabilityGoal
            ),
            dailyDriver: dailyDriver,
            emissionsSensitive: emissionsSensitive,
            existingMods: existingMods,
            elevation: nil,
            climate: nil,
            tireType: nil,
            weight: nil,
            city: city.isEmpty ? nil : city
        )

        return await withCheckedContinuation { continuation in
            sseClient.onProgress = { [weak self] progress in
                Task { @MainActor in
                    self?.pipelineStep = progress.step
                    if progress.status == .completed {
                        self?.completedPipelineSteps.insert(progress.step)
                    }
                }
            }

            sseClient.onComplete = { [weak self] buildId in
                Task { @MainActor in
                    self?.isGenerating = false
                    continuation.resume(returning: buildId)
                }
            }

            sseClient.onError = { [weak self] error in
                Task { @MainActor in
                    self?.error = error.error
                    self?.isGenerating = false
                    // If partial, still return the buildId
                    if error.partial == true, let buildId = error.buildId {
                        continuation.resume(returning: buildId)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }

            // Get token from keychain
            let token = KeychainService.shared.getSessionToken() ?? ""
            sseClient.startBuild(vehicle: vehicleInput, intent: intentInput, token: token)
        }
    }
}
