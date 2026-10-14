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

    var selectedBytes: Int64 {
        orphans.filter(\.isSelected).reduce(0) { $0 + $1.byteCount }
    }

    var selectedCount: Int {
        orphans.filter(\.isSelected).count
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        lastResult = nil
        progressLabel = L10n.string("orphan.scanning")

        let apps = await ApplicationsCatalog.listInstalledApps()
        let ids = Set(apps.map(\.bundleIdentifier))
        orphans = await LeftoverDiscovery.orphanLeftovers(installedBundleIDs: ids)
        progressLabel = L10n.format(
            "orphan.summary",
            Int64(orphans.count),
            ByteFormat.string(orphans.reduce(0) { $0 + $1.byteCount })
        )
        isLoading = false
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

    func cleanSelected() async {
        let selected = orphans.filter(\.isSelected)
        guard !selected.isEmpty, !isCleaning else { return }
        isCleaning = true
        errorMessage = nil
        progressLabel = L10n.string("orphan.cleaning")

        let report = await AppUninstall.trashLikePureMac(selected.map(\.url))
        lastResult = report.result
        CleanupHistoryStore.shared.record(result: report.result, source: .orphans)
        if !report.result.failed.isEmpty {
            if report.needsFullDiskAccess {
                errorMessage = L10n.format("apps.needs_fda_generic", Int64(report.result.failed.count))
            } else {
                errorMessage = L10n.format("apps.failed_paths", Int64(report.result.failed.count))
            }
        }
        isCleaning = false
        await refresh()
        if let lastResult, lastResult.failed.isEmpty {
            progressLabel = L10n.format("smartcare.freed", ByteFormat.string(lastResult.freedBytes))
        }
    }
}
