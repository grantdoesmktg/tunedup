import Foundation

// MARK: - Build Progress Models

struct ModProgress: Codable, Identifiable {
    var id: String { modId }

    let modId: String
    let status: ProgressStatus
    let purchasedAt: String?
    let installedAt: String?
    let notes: String?
}

enum ProgressStatus: String, Codable {
    case pending
    case purchased
    case installed
}

struct ProgressStats: Codable {
    let total: Int
    let purchased: Int
    let installed: Int

    var percentComplete: Double {
        guard total > 0 else { return 0 }
        return Double(installed) / Double(total) * 100
    }
}

// MARK: - API Response Types

struct BuildProgressResponse: Codable {
    let progress: [ModProgress]
    let stats: ProgressStats
}

struct ModProgressUpdateRequest: Codable {
    let status: ProgressStatus
    let notes: String?
}

// MARK: - Install Guide Models

struct InstallGuide: Codable {
    let title: String
    let recommendation: InstallRecommendation
    let shopReason: String?
    let difficulty: Int
    let timeEstimate: String
    let tools: [String]
    let steps: [InstallStep]
    let tips: [String]
    let warnings: [String]
}

enum InstallRecommendation: String, Codable {
    case diy
    case shop
}

struct InstallStep: Codable, Identifiable {
    var id: Int { number }

    let number: Int
    let title: String
    let description: String
    let warning: String?
}

struct InstallGuideResponse: Codable {
    let guide: InstallGuide
    let tokensUsed: Int
}

struct InstallGuideRequest: Codable {
    let modId: String
}
