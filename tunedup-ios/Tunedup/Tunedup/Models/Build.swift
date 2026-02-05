import Foundation

// MARK: - Build Model

struct Build: Codable, Identifiable {
    let id: String
    let createdAt: String
    let pipelineStatus: PipelineStatus
    let failedStep: String?

    let vehicle: VehicleProfile
    let intent: UserIntent
    let strategy: BuildStrategy?
    let plan: BuildPlan?
    let execution: ExecutionPlan?
    let performance: PerformanceEstimate?
    let sourcing: Sourcing?

    let presentation: BuildPresentation?
    let assumptions: [String]?
}

enum PipelineStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
}

// MARK: - Build List Response

struct BuildListResponse: Codable {
    let builds: [BuildSummary]
    let canCreateNew: Bool
}

struct BuildSummary: Codable, Identifiable {
    let id: String
    let createdAt: String
    let vehicle: VehicleSummary
    let summary: String?
    let pipelineStatus: PipelineStatus
    let statsPreview: StatsPreview?
}

struct VehicleSummary: Codable {
    let year: Int
    let make: String
    let model: String
    let trim: String

    var displayName: String {
        "\(year) \(make) \(model)"
    }

    var fullName: String {
        "\(year) \(make) \(model) \(trim)"
    }
}

struct StatsPreview: Codable {
    let hpGainRange: [Int]?
    let totalBudget: Int
}

// MARK: - Vehicle Profile (Step A Output)

struct VehicleProfile: Codable {
    let year: Int
    let make: String
    let model: String
    let trim: String
    let engine: String
    let displacement: String?
    let aspiration: Aspiration
    let drivetrain: Drivetrain
    let transmission: TransmissionType
    let factoryHp: Int
    let factoryTorque: Int
    let curbWeight: Int?
    let platform: String?

    enum CodingKeys: String, CodingKey {
        case year, make, model, trim, engine, displacement, aspiration
        case drivetrain, transmission, factoryHp, factoryTorque
        case curbWeight = "curb_weight"
        case platform
    }
}

enum Aspiration: String, Codable {
    case na
    case turbo
    case supercharged
    case twinturbo
}

enum Drivetrain: String, Codable {
    case fwd
    case rwd
    case awd
}

enum TransmissionType: String, Codable {
    case manual
    case auto
    case dct
    case cvt
    case unknown
}

// MARK: - User Intent (Step A Output)

struct UserIntent: Codable {
    let budget: Int
    let priorityRank: [String]
    let dailyDriver: Bool
    let emissionsSensitive: Bool
    let existingMods: [String]
    let city: String?
}

// MARK: - Build Strategy (Step B Output)

struct BuildStrategy: Codable {
    let archetype: String
    let archetypeRationale: String
    let stageCount: Int
    let budgetAllocation: [String: Double]
    let guardrails: Guardrails
    let keyFocus: [String]
}

struct Guardrails: Codable {
    let avoidFI: Bool
    let keepWarranty: Bool
    let emissionsLegal: Bool
    let dailyReliability: Bool
}

// MARK: - Build Plan (Step C Output)

struct BuildPlan: Codable {
    let stages: [Stage]
}

struct Stage: Codable, Identifiable {
    var id: Int { stageNumber }

    let stageNumber: Int
    let name: String
    let description: String
    let estimatedCost: CostRange
    let mods: [Mod]
    let synergyGroups: [SynergyGroup]
}

struct Mod: Codable, Identifiable {
    let id: String
    let category: String
    let name: String
    let description: String
    let justification: String
    let estimatedCost: CostRange
    let dependsOn: [String]
    let synergyWith: [String]
}

struct CostRange: Codable {
    let low: Int
    let high: Int

    var formatted: String {
        "$\(low.formattedWithCommas) - $\(high.formattedWithCommas)"
    }

    var midpoint: Int {
        (low + high) / 2
    }
}

struct SynergyGroup: Codable, Identifiable {
    let id: String
    let name: String
    let modIds: [String]
    let explanation: String
}

// MARK: - Execution Plan (Step D Output)

struct ExecutionPlan: Codable {
    let modExecutions: [ModExecution]
    let consolidatedTools: [Tool]
}

struct ModExecution: Codable {
    let modId: String
    let diyable: Bool
    let difficulty: Int // 1-5
    let timeEstimate: TimeEstimate
    let toolsRequired: [String]
    let shopType: String?
    let shopLaborEstimate: CostRange?
    let riskNotes: [String]
    let tips: [String]
}

struct TimeEstimate: Codable {
    let hours: HoursRange
}

struct HoursRange: Codable {
    let low: Double
    let high: Double

    var formatted: String {
        if low == high {
            return "\(low.formattedOneDecimal)h"
        }
        return "\(low.formattedOneDecimal)-\(high.formattedOneDecimal)h"
    }
}

struct Tool: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let estimatedCost: Int?
    let reusable: Bool
}

// MARK: - Performance Estimate (Step E Output)

struct PerformanceEstimate: Codable {
    let baseline: BaselinePerformance
    let afterStage: [String: StagePerformance]
    let assumptions: [String]
    let caveats: [String]
}

struct BaselinePerformance: Codable {
    let hp: Int
    let whp: Int
    let torque: Int
    let weight: Int
    let zeroToSixty: Double
    let quarterMile: QuarterMile
}

struct QuarterMile: Codable {
    let time: Double
    let trapSpeed: Int
}

struct StagePerformance: Codable {
    let hpGain: ValueRange
    let whpGain: ValueRange
    let torqueGain: ValueRange
    let estimatedHp: ValueRange
    let estimatedWhp: ValueRange
    let zeroToSixty: DoubleRange
    let quarterMile: QuarterMileRange
}

struct ValueRange: Codable {
    let low: Int
    let high: Int

    var formatted: String {
        if low == high {
            return "+\(low)"
        }
        return "+\(low)-\(high)"
    }

    var midpoint: Int {
        (low + high) / 2
    }
}

struct DoubleRange: Codable {
    let low: Double
    let high: Double

    var formatted: String {
        "\(low.formattedOneDecimal)-\(high.formattedOneDecimal)s"
    }
}

struct QuarterMileRange: Codable {
    let time: DoubleRange
    let trapSpeed: ValueRange
}

// MARK: - Sourcing (Step F Output)

struct Sourcing: Codable {
    let modSourcing: [ModSourcing]
    let shopTypes: [ShopTypeInfo]
}

struct ModSourcing: Codable {
    let modId: String
    let reputableBrands: [String]
    let searchQueries: [String]
    let whereToBuy: [String]
}

struct ShopTypeInfo: Codable {
    let type: String
    let forMods: [String]
    let searchQuery: String
}

// MARK: - Presentation (Step G Output)

struct BuildPresentation: Codable {
    let headline: String
    let summary: String
    let stageDescriptions: [String: String]
    let disclaimerText: String
}

// MARK: - Build Input Models

struct VehicleInput: Codable {
    var year: Int
    var make: String
    var model: String
    var trim: String
    var engine: String?
    var drivetrain: String?
    var fuel: String?
    var transmission: String // "manual", "auto", "unknown"
}

struct IntentInput: Codable {
    var budget: Int
    var goals: GoalSliders
    var dailyDriver: Bool
    var emissionsSensitive: Bool
    var existingMods: String
    var elevation: String?
    var climate: String?
    var tireType: String?
    var weight: Int?
    var city: String?
}

struct GoalSliders: Codable {
    var power: Int // 1-5
    var handling: Int // 1-5
    var reliability: Int // 1-5
}

struct BuildRequest: Codable {
    let vehicle: VehicleInput
    let intent: IntentInput
}
