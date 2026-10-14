import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class StartupEngine {
    var launchAgents: [LaunchAgentItem] = []
    var snapshots: [TimeMachineSnapshot] = []
    var isRefreshing = false
    var isWorking = false
    var progressLabel = L10n.string("startup.idle")
    var lastMessage: String?
    var errorMessage: String?

    var brokenCount: Int { launchAgents.filter(\.isBroken).count }
    var selectedAgentBytes: Int64 {
        launchAgents.filter { $0.isSelected && $0.isUserDomain }.reduce(0) { $0 + $1.byteCount }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        progressLabel = L10n.string("startup.refreshing")
        errorMessage = nil

        let agents = await Task.detached(priority: .userInitiated) {
            LaunchAgentScanner.scan()
        }.value
        let snaps = await Task.detached(priority: .utility) {
            TimeMachineSnapshots.listLocal()
        }.value

        launchAgents = agents
        snapshots = snaps
        progressLabel = L10n.format(
            "startup.summary",
            Int64(agents.count),
            Int64(brokenCount),
            Int64(snaps.count)
        )
        isRefreshing = false
    }

    func toggleAgent(_ id: LaunchAgentItem.ID) {
        guard let idx = launchAgents.firstIndex(where: { $0.id == id }) else { return }
        guard launchAgents[idx].isUserDomain else { return }
        launchAgents[idx].isSelected.toggle()
    }

    func toggleSnapshot(_ id: String) {
        guard let idx = snapshots.firstIndex(where: { $0.id == id }) else { return }
        snapshots[idx].isSelected.toggle()
    }

    func removeSelectedAgents() async {
        let selected = launchAgents.filter { $0.isSelected && $0.isUserDomain }
        guard !selected.isEmpty else { return }
        isWorking = true
        progressLabel = L10n.string("perf.moving_agents")
        let items = selected.map {
            ScanItem(category: .brokenLaunchAgents, url: $0.url, byteCount: $0.byteCount, displayName: $0.label)
        }
        let result = await Cleaner.moveToTrash(items)
        CleanupHistoryStore.shared.record(result: result, source: .startup)
        if result.failed.isEmpty {
            lastMessage = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
        } else {
            errorMessage = L10n.format("perf.agents_failed", Int64(result.failed.count))
        }
        isWorking = false
        await refresh()
    }

    func deleteSelectedSnapshots() async {
        let selected = snapshots.filter(\.isSelected)
        guard !selected.isEmpty else { return }
        isWorking = true
        var ok = 0
        var fail = 0
        for snap in selected {
            progressLabel = L10n.format("startup.deleting_snapshot", snap.dateString)
            let result = await TimeMachineSnapshots.deleteLocal(snap.dateString)
            if result.ok { ok += 1 } else { fail += 1 }
        }
        if fail == 0 {
            lastMessage = L10n.format("startup.snapshots_deleted", Int64(ok))
            errorMessage = nil
        } else {
            errorMessage = L10n.format("startup.snapshots_failed", Int64(fail))
        }
        isWorking = false
        await refresh()
    }

    func thinAllSnapshots() async {
        isWorking = true
        progressLabel = L10n.string("maint.thinLocalSnapshots.title")
        let result = await PrivilegedBridge.thinLocalSnapshots()
        lastMessage = result.success
            ? L10n.string("maint.thinLocalSnapshots.ok")
            : (result.message.isEmpty ? L10n.string("maint.thinLocalSnapshots.fail") : result.message)
        if !result.success { errorMessage = lastMessage }
        isWorking = false
        await refresh()
    }

    func openLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    func revealAgent(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
