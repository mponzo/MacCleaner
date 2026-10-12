import Foundation
import Observation

@MainActor
@Observable
final class PrivilegedHelperEngine {
    var statusText = PrivilegedBridge.statusSummary()
    var isBusy = false
    var lastMessage: String?
    var lastError: String?
    var systemCacheBytes: Int64 = 0
    var systemLogBytes: Int64 = 0
    var brokenSystemAgents = 0

    func refreshStatus() async {
        isBusy = true
        statusText = PrivilegedBridge.statusSummary()

        async let caches = SystemCachesScanner().scan()
        async let logs = SystemLogsScanner().scan()
        async let agents = SystemLaunchAgentsScanner().scan()
        let c = await caches
        let l = await logs
        let a = await agents
        systemCacheBytes = c.reduce(0) { $0 + $1.byteCount }
        systemLogBytes = l.reduce(0) { $0 + $1.byteCount }
        brokenSystemAgents = a.count
        lastMessage = L10n.format(
            "priv.summary",
            ByteFormat.string(systemCacheBytes),
            ByteFormat.string(systemLogBytes),
            Int64(brokenSystemAgents)
        )
        isBusy = false
    }

    func runFlushDNS() async {
        await run(L10n.string("priv.flush_dns")) {
            await PrivilegedBridge.flushDNS()
        }
    }

    func runThinSnapshots() async {
        await run(L10n.string("priv.thin_snapshots")) {
            await PrivilegedBridge.thinLocalSnapshots()
        }
    }

    private func run(_ label: String, _ work: () async -> PrivilegedCommandResult) async {
        guard !isBusy else { return }
        isBusy = true
        lastError = nil
        lastMessage = L10n.format("priv.running", label)
        let result = await work()
        if result.success {
            lastMessage = L10n.format("priv.completed", label)
        } else {
            lastError = result.message.isEmpty ? L10n.format("priv.failed", label) : result.message
            lastMessage = lastError
        }
        isBusy = false
    }
}
