import Foundation
import SwiftUI
import Combine

// MARK: - Auth Service
// Manages authentication state across the app

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var authState: AuthState = .unknown
    @Published var currentUser: User?

    private let apiClient = APIClient.shared
    private let keychain = KeychainService.shared

    private init() {
        checkAuthState()
    }

    // MARK: - Check Auth State

    func checkAuthState() {
        if let token = keychain.getSessionToken(),
           let email = keychain.getUserEmail(),
           let userId = keychain.getUserId() {
            // We have a stored session, user needs to verify PIN or is already authenticated
            // For now, assume authenticated if we have a token
            // In production, you might want to verify the token is still valid
            currentUser = User(id: userId, email: email, hasPin: true)
            authState = .authenticated(currentUser!)
        } else {
            authState = .unauthenticated
        }
    }

    // MARK: - Magic Link Flow

    func requestMagicLink(email: String) async throws {
        let _ = try await apiClient.requestMagicLink(email: email)
        authState = .awaitingMagicLink(email: email)
    }

    func verifyMagicLink(token: String) async throws {
        let response = try await apiClient.verifyMagicLink(token: token)

        // Save to keychain
        keychain.saveSessionToken(response.sessionToken)
        keychain.saveUserInfo(email: response.user.email, userId: response.user.id)

        currentUser = response.user

        if response.user.hasPin {
            authState = .awaitingPin
        } else {
            authState = .authenticated(response.user)
        }
    }

    // MARK: - PIN Flow

    func setPin(_ pin: String) async throws {
        let _ = try await apiClient.setPin(pin)
        // PIN set successfully, user is now authenticated
        if let user = currentUser {
            let updatedUser = User(id: user.id, email: user.email, hasPin: true)
            currentUser = updatedUser
            authState = .authenticated(updatedUser)
        }
    }

    func verifyPin(_ pin: String) async throws -> Bool {
        let response = try await apiClient.verifyPin(pin)
        if response.verified, let user = currentUser {
            authState = .authenticated(user)
            return true
        }
        return false
    }

    // MARK: - Logout

    func logout() {
        keychain.clearAll()
        currentUser = nil
        authState = .unauthenticated
    }
}

// MARK: - Auth View Model
// ViewModel for auth-related views

@MainActor
class AuthViewModel: ObservableObject {
    @Published var authState: AuthState = .unauthenticated
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let authService = AuthService.shared
    private let apiClient = APIClient.shared

    init() {
        // Sync with auth service
        self.authState = authService.authState
    }

    // MARK: - Magic Link

    func requestMagicLink(email: String) async {
        isLoading = true
        error = nil

        do {
            try await authService.requestMagicLink(email: email)
            authState = .awaitingMagicLink(email: email)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func verifyMagicLink(token: String) async {
        isLoading = true
        error = nil

        do {
            try await authService.verifyMagicLink(token: token)
            authState = authService.authState
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - PIN

    func setPin(_ pin: String) async -> Bool {
        isLoading = true
        error = nil

        do {
            try await authService.setPin(pin)
            authState = authService.authState
            isLoading = false
            return true
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func verifyPin(_ pin: String) async -> Bool {
        isLoading = true
        error = nil

        do {
            let success = try await authService.verifyPin(pin)
            authState = authService.authState
            isLoading = false
            return success
        } catch {
            self.error = "Incorrect PIN"
            isLoading = false
            return false
        }
    }

    // MARK: - Logout

    func logout() {
        authService.logout()
        authState = .unauthenticated
    }
}
