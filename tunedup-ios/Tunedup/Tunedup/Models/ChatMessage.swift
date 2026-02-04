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
}

// MARK: - Chat Constants

enum ChatConstants {
    static let maxMessageLength = 500
    static let maxResponseWords = 300
}
