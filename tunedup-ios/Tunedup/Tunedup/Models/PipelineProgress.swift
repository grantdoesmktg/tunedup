import Foundation

// MARK: - Pipeline Progress

struct PipelineProgress: Codable {
    let step: PipelineStep
    let status: StepStatus
    let message: String?
    let data: AnyCodable?
}

enum PipelineStep: String, Codable, CaseIterable {
    case normalize
    case strategy
    case synergy
    case execution
    case performance
    case sourcing
    case tone

    var displayName: String {
        switch self {
        case .normalize: return "Understanding"
        case .strategy: return "Planning"
        case .synergy: return "Optimizing"
        case .execution: return "DIY Analysis"
        case .performance: return "Estimating"
        case .sourcing: return "Parts List"
        case .tone: return "Final Polish"
        }
    }

    var loadingMessage: String {
        switch self {
        case .normalize: return "Understanding your car..."
        case .strategy: return "Planning stages..."
        case .synergy: return "Optimizing synergy..."
        case .execution: return "Planning installation..."
        case .performance: return "Estimating performance..."
        case .sourcing: return "Building parts list..."
        case .tone: return "Final polish..."
        }
    }

    var index: Int {
        PipelineStep.allCases.firstIndex(of: self) ?? 0
    }

    static var totalSteps: Int {
        allCases.count
    }
}

enum StepStatus: String, Codable {
    case pending
    case running
    case completed
    case failed
}

// MARK: - Build Complete

struct BuildComplete: Codable {
    let buildId: String
    let success: Bool
}

// MARK: - Pipeline Error

struct PipelineError: Codable, Error {
    let step: String?
    let error: String
    let partial: Bool?
    let buildId: String?
}

// MARK: - AnyCodable for dynamic data

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
