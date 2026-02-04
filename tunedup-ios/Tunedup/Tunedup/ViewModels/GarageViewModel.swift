import Foundation
import SwiftUI
import Combine

@MainActor
class GarageViewModel: ObservableObject {
    @Published var builds: [BuildSummary] = []
    @Published var canCreateNew: Bool = true
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let apiClient = APIClient.shared

    func fetchBuilds() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.getBuilds()
            builds = response.builds
            canCreateNew = response.canCreateNew
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func deleteBuild(_ buildId: String) async -> Bool {
        do {
            try await apiClient.deleteBuild(buildId)
            builds.removeAll { $0.id == buildId }
            canCreateNew = builds.count < 3
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
