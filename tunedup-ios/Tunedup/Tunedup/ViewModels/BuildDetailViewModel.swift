import Foundation
import Combine

@MainActor
class BuildDetailViewModel: ObservableObject {
    @Published var build: Build?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func fetchBuild(_ buildId: String) async {
        isLoading = true
        error = nil

        do {
            build = try await apiClient.getBuild(buildId)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteBuild() async -> Bool {
        guard let buildId = build?.id else { return false }

        do {
            try await apiClient.deleteBuild(buildId)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
