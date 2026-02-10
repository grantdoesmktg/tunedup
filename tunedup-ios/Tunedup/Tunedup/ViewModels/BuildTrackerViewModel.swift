import Foundation
import Combine

@MainActor
class BuildTrackerViewModel: ObservableObject {
    @Published var progress: [String: ModProgress] = [:]
    @Published var stats: ProgressStats?
    @Published var isLoading = false
    @Published var error: String?

    private let apiClient = APIClient.shared
    private var buildId: String?

    func loadProgress(buildId: String) async {
        self.buildId = buildId
        isLoading = true
        error = nil

        do {
            let response = try await apiClient.getBuildProgress(buildId)

            // Convert array to dictionary for easy lookup
            var progressDict: [String: ModProgress] = [:]
            for p in response.progress {
                progressDict[p.modId] = p
            }
            self.progress = progressDict
            self.stats = response.stats
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func updateProgress(modId: String, status: ProgressStatus, notes: String? = nil) async {
        guard let buildId = buildId else { return }

        // Optimistic update
        let previousProgress = progress[modId]
        let optimisticProgress = ModProgress(
            modId: modId,
            status: status,
            purchasedAt: status != .pending ? (previousProgress?.purchasedAt ?? ISO8601DateFormatter().string(from: Date())) : nil,
            installedAt: status == .installed ? ISO8601DateFormatter().string(from: Date()) : nil,
            notes: notes ?? previousProgress?.notes
        )
        progress[modId] = optimisticProgress
        updateLocalStats()

        do {
            let updatedProgress = try await apiClient.updateModProgress(
                buildId: buildId,
                modId: modId,
                status: status,
                notes: notes
            )
            progress[modId] = updatedProgress

            // Refresh full stats from server
            let response = try await apiClient.getBuildProgress(buildId)
            self.stats = response.stats
        } catch {
            // Revert on failure
            if let previous = previousProgress {
                progress[modId] = previous
            } else {
                progress.removeValue(forKey: modId)
            }
            updateLocalStats()
            self.error = error.localizedDescription
        }
    }

    private func updateLocalStats() {
        guard let currentStats = stats else { return }

        let purchased = progress.values.filter { $0.status == .purchased || $0.status == .installed }.count
        let installed = progress.values.filter { $0.status == .installed }.count

        stats = ProgressStats(
            total: currentStats.total,
            purchased: purchased,
            installed: installed
        )
    }
}
