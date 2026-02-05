import Foundation

// MARK: - API Client
// REST API client for TunedUp backend

class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://www.tunedup.dev"

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Auth Endpoints

    func requestMagicLink(email: String) async throws -> AuthRequestLinkResponse {
        let request = AuthRequestLinkRequest(email: email)
        return try await post("/api/auth/request-link", body: request)
    }

    func verifyCode(email: String, code: String) async throws -> AuthVerifyResponse {
        let request = AuthVerifyRequest(email: email, code: code)
        return try await post("/api/auth/verify", body: request)
    }

    // MARK: - PIN Endpoints

    func setPin(_ pin: String) async throws -> PinSetResponse {
        let request = PinSetRequest(pin: pin)
        return try await post("/api/pin/set", body: request, authenticated: true)
    }

    func verifyPin(_ pin: String) async throws -> PinVerifyResponse {
        let request = PinVerifyRequest(pin: pin)
        return try await post("/api/pin/verify", body: request, authenticated: true)
    }

    // MARK: - Build Endpoints

    func getBuilds() async throws -> BuildListResponse {
        return try await get("/api/builds", authenticated: true)
    }

    func getBuild(_ id: String) async throws -> Build {
        return try await get("/api/builds/\(id)", authenticated: true)
    }

    func deleteBuild(_ id: String) async throws {
        let _: EmptyResponse = try await delete("/api/builds/\(id)", authenticated: true)
    }

    // MARK: - Chat Endpoints

    func sendChatMessage(buildId: String, message: String) async throws -> ChatResponse {
        let request = ChatRequest(buildId: buildId, message: message)
        return try await post("/api/chat", body: request, authenticated: true)
    }

    // MARK: - Usage Endpoints

    func getUsage() async throws -> UsageResponse {
        return try await get("/api/usage", authenticated: true)
    }

    // MARK: - HTTP Methods

    private func get<T: Decodable>(_ path: String, authenticated: Bool = false) async throws -> T {
        let request = try buildRequest(path: path, method: "GET", authenticated: authenticated)
        return try await execute(request)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B, authenticated: Bool = false) async throws -> T {
        var request = try buildRequest(path: path, method: "POST", authenticated: authenticated)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func delete<T: Decodable>(_ path: String, authenticated: Bool = false) async throws -> T {
        let request = try buildRequest(path: path, method: "DELETE", authenticated: authenticated)
        return try await execute(request)
    }

    // MARK: - Request Building

    private func buildRequest(path: String, method: String, authenticated: Bool) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if authenticated {
            guard let token = KeychainService.shared.getSessionToken() else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Request Execution

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("Decoding error: \(error)")
                throw APIError.decodingError(error)
            }

        case 400:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw APIError.badRequest(errorResponse.error)
            }
            throw APIError.badRequest("Bad request")

        case 401:
            throw APIError.unauthorized

        case 403:
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data),
               errorResponse.error == "upgrade_required" {
                throw APIError.upgradeRequired
            }
            throw APIError.forbidden

        case 404:
            throw APIError.notFound

        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)

        default:
            throw APIError.unknown(httpResponse.statusCode)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case badRequest(String)
    case upgradeRequired
    case serverError(Int)
    case decodingError(Error)
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please log in again"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .badRequest(let message):
            return message
        case .upgradeRequired:
            return "Token limit reached. Please upgrade."
        case .serverError(let code):
            return "Server error (\(code))"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .unknown(let code):
            return "Unknown error (\(code))"
        }
    }
}

// MARK: - Response Types

struct ErrorResponse: Decodable {
    let error: String
    let message: String?
}

struct EmptyResponse: Decodable {}
