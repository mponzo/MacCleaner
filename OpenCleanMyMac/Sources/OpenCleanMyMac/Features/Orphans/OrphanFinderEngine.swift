import Foundation
import Observation

@MainActor
@Observable
final class OrphanFinderEngine {
    var orphans: [AppLeftover] = []
    var isLoading = false
    var isCleaning = false
    var progressLabel = L10n.string("orphan.idle")
    var lastResult: CleanResult?
    var errorMessage: String?
    var operationProgress: Double?
    var operationDetail: String?

    private var workTask: Task<Void, Never>?

    var isBusy: Bool { isLoading || isCleaning }

    var selectedBytes: Int64 {
        orphans.filter(\.isSelected).reduce(0) { $0 + $1.byteCount }
    }

    var selectedCount: Int {
        orphans.filter(\.isSelected).count
    }

    func refresh() {
        guard !isBusy else { return }
        workTask?.cancel()
        workTask = Task { await self.performRefresh() }
    }

    func cleanSelected() {
        guard !isBusy else { return }
        let selected = orphans.filter(\.isSelected)
        guard !selected.isEmpty else { return }
        workTask?.cancel()
        workTask = Task { await self.performClean(selected: selected) }
    }

    func stop() {
        workTask?.cancel()
        workTask = nil
        if isLoading || isCleaning {
            progressLabel = L10n.string("smartcare.stopped")
        }
        isLoading = false
        isCleaning = false
        operationProgress = nil
        operationDetail = nil
    }

    func toggle(_ id: AppLeftover.ID) {
        guard let idx = orphans.firstIndex(where: { $0.id == id }) else { return }
        orphans[idx].isSelected.toggle()
    }

    func selectAll(_ selected: Bool) {
        for i in orphans.indices {
            orphans[i].isSelected = selected
        }
    }

    private func performRefresh() async {
        isLoading = true
        operationProgress = -1
        operationDetail = nil
        errorMessage = nil
        lastResult = nil
        progressLabel = L10n.string("orphan.scanning")

        let apps = await ApplicationsCatalog.listInstalledApps()
        if Task.isCancelled {
            isLoading = false
            operationProgress = nil
            return
        }
        let ids = Set(apps.map(\.bundleIdentifier))
        orphans = await LeftoverDiscovery.orphanLeftovers(installedBundleIDs: ids)
        if Task.isCancelled {
            isLoading = false
            operationProgress = nil
            return
        }
        progressLabel = L10n.format(
            "orphan.summary",
            Int64(orphans.count),
            ByteFormat.string(orphans.reduce(0) { $0 + $1.byteCount })
        )
        isLoading = false
        operationProgress = nil
        operationDetail = nil
    }

    private func performClean(selected: [AppLeftover]) async {
        isCleaning = true
        errorMessage = nil
        progressLabel = L10n.string("orphan.cleaning")
        let total = max(selected.count, 1)
        var completed = 0
        var freed: Int64 = 0
        var moved = 0
        var failed: [(URL, String)] = []
        var needsFDA = false
        operationProgress = 0
        operationDetail = L10n.format("operation.step", Int64(0), Int64(total))

        for leftover in selected {
            if Task.isCancelled { break }
            progressLabel = L10n.format("dev.cleaning_item", leftover.url.lastPathComponent)
            let report = await AppUninstall.trashLikePureMac([leftover.url])
            freed += report.result.freedBytes
            moved += report.result.movedCount
            failed.append(contentsOf: report.result.failed)
            if report.needsFullDiskAccess { needsFDA = true }
            completed += 1
            operationProgress = Double(completed) / Double(total)
            operationDetail = L10n.format("operation.step", Int64(completed), Int64(total))
        }

        let result = CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
        let wasCancelled = Task.isCancelled
        isCleaning = false
        operationProgress = nil
        operationDetail = nil

        if moved > 0 || freed > 0 {
            lastResult = result
            CleanupHistoryStore.shared.record(result: result, source: .orphans)
        }
        if wasCancelled {
            progressLabel = L10n.string("smartcare.stopped")
            return
        }
        if !failed.isEmpty {
            if needsFDA {
                errorMessage = L10n.format("apps.needs_fda_generic", Int64(failed.count))
            } else {
                errorMessage = L10n.format("apps.failed_paths", Int64(failed.count))
            }
        }
        await performRefresh()
        if failed.isEmpty {
            progressLabel = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
        }
    }
}
