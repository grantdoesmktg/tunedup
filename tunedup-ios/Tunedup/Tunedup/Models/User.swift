import Foundation

// MARK: - User Model

struct User: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let hasPin: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case hasPin
    }
}

// MARK: - Auth Models

struct AuthRequestLinkRequest: Codable {
    let email: String
}

struct AuthRequestLinkResponse: Codable {
    let success: Bool
    let message: String
}

struct AuthVerifyRequest: Codable {
    let email: String
    let code: String
}

struct AuthVerifyResponse: Codable {
    let sessionToken: String
    let user: User
}

struct PinSetRequest: Codable {
    let pin: String
}

struct PinSetResponse: Codable {
    let success: Bool
}

struct PinVerifyRequest: Codable {
    let pin: String
    let userId: String?
}

struct PinVerifyResponse: Codable {
    let verified: Bool
    let sessionToken: String?
}

// MARK: - Usage Model

struct UsageResponse: Codable {
    let used: Int
    let limit: Int
    let percentRemaining: Double
    let warning: UsageWarning?
    let blocked: Bool
    let resetsAt: String

    enum UsageWarning: String, Codable {
        case fiftyPercent = "50_percent"
        case tenPercent = "10_percent"
    }
}

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case unauthenticated
    case awaitingCode(email: String)
    case awaitingPin
    case authenticated(User)

    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
}
