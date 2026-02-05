import Foundation
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var error: String?
    @Published var showContextWarning: Bool = false
    @Published var contextPercent: Double = 0
    @Published var contextWarningDismissed: Bool = false
    @Published var threadId: String?

    private let apiClient = APIClient.shared

    func sendMessage(buildId: String) async {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        guard trimmedText.count <= ChatConstants.maxMessageLength else {
            error = "Message too long (max \(ChatConstants.maxMessageLength) characters)"
            return
        }

        // Add user message immediately
        let userMessage = ChatMessage(
            role: .user,
            content: trimmedText
        )
        messages.append(userMessage)
        inputText = ""

        // Show typing indicator
        isTyping = true
        error = nil

        do {
            let response = try await apiClient.sendChatMessage(buildId: buildId, message: trimmedText)

            // Add assistant response
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response.reply
            )
            messages.append(assistantMessage)
            threadId = response.threadId
            handleContextUsage(response.context)
        } catch let apiError as APIError {
            switch apiError {
            case .upgradeRequired:
                error = "You've used all your tokens this month. Upgrade to continue chatting."
            default:
                error = apiError.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }

        isTyping = false
    }

    func loadHistory(buildId: String) async {
        do {
            let response = try await apiClient.getChatHistory(buildId: buildId)
            messages = response.messages
            threadId = response.threadId
            handleContextUsage(response.context)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func resetChat(buildId: String) async {
        do {
            try await apiClient.resetChat(buildId: buildId)
            messages = []
            threadId = nil
            error = nil
            showContextWarning = false
            contextWarningDismissed = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    func dismissContextWarning() {
        contextWarningDismissed = true
        showContextWarning = false
    }

    private func handleContextUsage(_ usage: ChatContextUsage) {
        contextPercent = usage.percent
        if usage.warning && !contextWarningDismissed {
            showContextWarning = true
        }
    }
}
