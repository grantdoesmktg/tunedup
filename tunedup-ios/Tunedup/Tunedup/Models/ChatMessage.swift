import Foundation

// MARK: - Chat Models

struct ChatMessage: Codable, Identifiable {
    let id: String
    let role: ChatRole
    let content: String
    let createdAt: Date

    init(id: String = UUID().uuidString, role: ChatRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
}

// MARK: - Chat Request/Response

struct ChatRequest: Codable {
    let buildId: String
    let message: String
}

struct ChatResponse: Codable {
    let reply: String
    let threadId: String
    let context: ChatContextUsage
}

struct ChatHistoryResponse: Codable {
    let threadId: String?
    let messages: [ChatMessage]
    let context: ChatContextUsage
}

struct ChatContextUsage: Codable {
    let used: Int
    let limit: Int
    let percent: Double
    let warning: Bool
}

// MARK: - Chat Constants

enum ChatConstants {
    static let maxMessageLength = 500
    static let maxResponseWords = 300
}
