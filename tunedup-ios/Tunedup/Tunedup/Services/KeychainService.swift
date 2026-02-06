import Foundation
import Security

// MARK: - Keychain Service
// Secure storage for session tokens and credentials

class KeychainService {
    static let shared = KeychainService()

    private let serviceName = "dev.tunedup.app"

    private enum Keys {
        static let sessionToken = "session_token"
        static let userEmail = "user_email"
        static let userId = "user_id"
        static let lastPinVerifiedAt = "pin_verified_at"
    }

    private init() {}

    // MARK: - Session Token

    func saveSessionToken(_ token: String) {
        save(key: Keys.sessionToken, data: token.data(using: .utf8)!)
    }

    func getSessionToken() -> String? {
        guard let data = load(key: Keys.sessionToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteSessionToken() {
        delete(key: Keys.sessionToken)
    }

    // MARK: - User Info

    func saveUserInfo(email: String, userId: String) {
        save(key: Keys.userEmail, data: email.data(using: .utf8)!)
        save(key: Keys.userId, data: userId.data(using: .utf8)!)
    }

    func getUserEmail() -> String? {
        guard let data = load(key: Keys.userEmail) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func getUserId() -> String? {
        guard let data = load(key: Keys.userId) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteUserInfo() {
        delete(key: Keys.userEmail)
        delete(key: Keys.userId)
    }

    // MARK: - Clear All

    func clearAll() {
        deleteSessionToken()
        deleteUserInfo()
        delete(key: Keys.lastPinVerifiedAt)
    }

    // MARK: - PIN Verification Timestamp

    func saveLastPinVerified(at date: Date) {
        let formatter = ISO8601DateFormatter()
        let value = formatter.string(from: date)
        save(key: Keys.lastPinVerifiedAt, data: value.data(using: .utf8)!)
    }

    func getLastPinVerifiedAt() -> Date? {
        guard let data = load(key: Keys.lastPinVerifiedAt),
              let value = String(data: data, encoding: .utf8) else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: value)
    }

    // MARK: - Keychain Operations

    private func save(key: String, data: Data) {
        // Delete existing item first
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save error: \(status)")
        }
    }

    private func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Check if logged in

    var isLoggedIn: Bool {
        return getSessionToken() != nil
    }
}
