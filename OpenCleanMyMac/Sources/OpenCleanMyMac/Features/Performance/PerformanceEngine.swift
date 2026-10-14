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

    /// System Monitor controls
    var processQuery = ""
    var sortKey: ProcessSortKey = .memory
    var sortAscending = false
    var showAllProcesses = false
    var metricsExpanded = true
    var processesExpanded = true

    private var timerTask: Task<Void, Never>?
    private var listedProcessCount = 0

    var brokenAgentCount: Int { launchAgents.filter(\.isBroken).count }
    var selectedAgentBytes: Int64 {
        launchAgents.filter { $0.isSelected && $0.isUserDomain }.reduce(0) { $0 + $1.byteCount }
    }

    var processGroups: [ProcessGroup] {
        let filtered = filteredProcesses
        let groups = Self.groupHelpers(filtered)
        return sortGroups(groups)
    }

    var filteredProcesses: [ProcessInfoRow] {
        let q = processQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return processes }
        return processes.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(q) ?? false)
                || String($0.pid).contains(q)
        }
    }

    func startPolling() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            // Warm-up sample so the second tick can compute CPU deltas.
            await self?.refreshLive()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.refreshLive()
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
        let showAll = showAllProcesses
        let snap = await Task.detached(priority: .utility) {
            MetricsCollector.shared.snapshot(limit: showAll ? nil : 40)
        }.value
        metrics = snap.0
        processes = snap.1
        listedProcessCount = snap.0.processCount
        if metrics?.cpuLoadPercent == 0, processes.allSatisfy({ $0.cpuPercent == 0 }) {
            progressLabel = L10n.string("perf.cpu_warming")
        }
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

    // MARK: - Grouping / sorting

    nonisolated private static func groupHelpers(_ rows: [ProcessInfoRow]) -> [ProcessGroup] {
        var byBundle: [String: [ProcessInfoRow]] = [:]
        var singles: [ProcessInfoRow] = []

        for row in rows {
            if let bundleID = row.bundleIdentifier, !bundleID.isEmpty {
                byBundle[bundleID, default: []].append(row)
            } else {
                singles.append(row)
            }
        }

        var groups: [ProcessGroup] = []
        for (bundleID, members) in byBundle {
            let primary = members.first(where: { !$0.isHelper })
                ?? members.max(by: { $0.memoryBytes < $1.memoryBytes })
                ?? members[0]
            let helpers = members.filter { $0.pid != primary.pid }
                .sorted { $0.memoryBytes > $1.memoryBytes }
            groups.append(ProcessGroup(id: bundleID, primary: primary, helpers: helpers))
        }
        for row in singles {
            groups.append(ProcessGroup(id: "pid:\(row.pid)", primary: row, helpers: []))
        }
        return groups
    }

    private func sortGroups(_ groups: [ProcessGroup]) -> [ProcessGroup] {
        groups.sorted { lhs, rhs in
            let ascending = sortAscending
            switch sortKey {
            case .memory:
                return ascending
                    ? lhs.totalMemoryBytes < rhs.totalMemoryBytes
                    : lhs.totalMemoryBytes > rhs.totalMemoryBytes
            case .cpu:
                return ascending
                    ? lhs.totalCPUPercent < rhs.totalCPUPercent
                    : lhs.totalCPUPercent > rhs.totalCPUPercent
            case .name:
                let cmp = lhs.primary.name.localizedCaseInsensitiveCompare(rhs.primary.name)
                return ascending ? cmp == .orderedAscending : cmp == .orderedDescending
            }
        }
    }
}
