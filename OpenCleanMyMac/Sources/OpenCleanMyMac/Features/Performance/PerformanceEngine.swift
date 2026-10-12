import Foundation
import Observation

@MainActor
@Observable
final class PerformanceEngine {
    var metrics: SystemMetrics?
    var processes: [ProcessInfoRow] = []
    var launchAgents: [LaunchAgentItem] = []
    var isRefreshing = false
    var isRunningTask = false
    var progressLabel = L10n.string("smartcare.idle")
    var lastTaskResult: MaintenanceTaskResult?
    var lastCleanResult: CleanResult?
    var errorMessage: String?
    private var timerTask: Task<Void, Never>?

    var brokenAgentCount: Int { launchAgents.filter(\.isBroken).count }
    var selectedAgentBytes: Int64 {
        launchAgents.filter { $0.isSelected && $0.isUserDomain }.reduce(0) { $0 + $1.byteCount }
    }

    func startPolling() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshLive()
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    func stopPolling() {
        timerTask?.cancel()
        timerTask = nil
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        progressLabel = L10n.string("perf.refreshing")
        await refreshLive()
        launchAgents = await Task.detached(priority: .userInitiated) {
            LaunchAgentScanner.scan()
        }.value
        progressLabel = L10n.format("perf.agents_summary", Int64(launchAgents.count), Int64(brokenAgentCount))
        isRefreshing = false
    }

    func refreshLive() async {
        let snap = await Task.detached(priority: .utility) {
            let metrics = MetricsCollector.snapshot()
            let processes = MetricsCollector.topProcesses()
            var merged = metrics
            merged.processCount = processes.count
            return (merged, processes)
        }.value
        metrics = snap.0
        processes = snap.1
    }

    func toggleAgent(_ id: LaunchAgentItem.ID) {
        guard let idx = launchAgents.firstIndex(where: { $0.id == id }) else { return }
        guard launchAgents[idx].isUserDomain else { return }
        launchAgents[idx].isSelected.toggle()
    }

    func removeSelectedAgents() async {
        let selected = launchAgents.filter { $0.isSelected && $0.isUserDomain }
        guard !selected.isEmpty else { return }
        isRunningTask = true
        progressLabel = L10n.string("perf.moving_agents")
        let items = selected.map {
            ScanItem(category: .userCaches, url: $0.url, byteCount: $0.byteCount, displayName: $0.label, isSelected: true)
        }
        let result = await Cleaner.moveToTrash(items)
        lastCleanResult = result
        if !result.failed.isEmpty {
            errorMessage = L10n.format("perf.agents_failed", Int64(result.failed.count))
        }
        isRunningTask = false
        await refreshAll()
    }

    func runMaintenance(_ task: MaintenanceTaskID) async {
        guard !isRunningTask else { return }
        isRunningTask = true
        progressLabel = L10n.format("perf.running_task", task.title)
        errorMessage = nil
        let result = await MaintenanceRunner.run(task)
        lastTaskResult = result
        if !result.success {
            errorMessage = result.message
        }
        progressLabel = result.message
        isRunningTask = false
        await refreshLive()
    }
}
