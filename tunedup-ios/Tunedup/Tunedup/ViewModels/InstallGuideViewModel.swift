import Foundation

@MainActor
class InstallGuideViewModel: ObservableObject {
    @Published var guide: InstallGuide?
    @Published var isLoading = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func generateGuide(buildId: String, modId: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.generateInstallGuide(buildId: buildId, modId: modId)
            self.guide = response.guide
        } catch let apiError as APIError {
            if case .upgradeRequired = apiError {
                self.error = "You've reached your token limit. Upgrade to generate more install guides."
            } else {
                self.error = apiError.localizedDescription
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
