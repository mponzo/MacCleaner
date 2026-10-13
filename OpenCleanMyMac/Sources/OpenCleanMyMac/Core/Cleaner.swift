import Foundation

enum Cleaner {
    /// Moves selected items to Trash. System/allowlisted paths use the privileged admin bridge.
    /// User apps under `/Applications` use PureMac-style trashItem → Finder → admin.
    static func moveToTrash(
        _ items: [ScanItem],
        isCancelled: () -> Bool = { false }
    ) async -> CleanResult {
        let selected = items.filter { $0.isSelected && $0.category.isCleanable }

        var appBundles: [ScanItem] = []
        var regular: [ScanItem] = []
        var privileged: [ScanItem] = []
        var denied: [(URL, String)] = []

        for item in selected {
            let url = item.url
            if PrivilegedPathPolicy.isUserApplicationBundle(url) {
                appBundles.append(item)
            } else if !PrivilegedPathPolicy.needsPrivilege(for: url) {
                regular.append(item)
            } else if PrivilegedPathPolicy.isRemovable(url) {
                privileged.append(item)
            } else {
                denied.append((url, L10n.string("priv.allowlist_denied")))
            }
        }

        let appResult = await uninstallAppBundles(appBundles, isCancelled: isCancelled)
        if isCancelled() {
            return CleanResult(
                freedBytes: appResult.freedBytes,
                movedCount: appResult.movedCount,
                failed: appResult.failed + denied
            )
        }

        let regularResult = moveRegularToTrash(regular, isCancelled: isCancelled)
        if isCancelled() {
            return CleanResult(
                freedBytes: appResult.freedBytes + regularResult.freedBytes,
                movedCount: appResult.movedCount + regularResult.movedCount,
                failed: appResult.failed + regularResult.failed + denied
            )
        }

        let privilegedURLs = privileged.map(\.url)
        let privilegedResult: CleanResult
        if privilegedURLs.isEmpty {
            privilegedResult = CleanResult(freedBytes: 0, movedCount: 0, failed: [])
        } else {
            privilegedResult = await PrivilegedBridge.removePaths(privilegedURLs)
        }

        return CleanResult(
            freedBytes: appResult.freedBytes + regularResult.freedBytes + privilegedResult.freedBytes,
            movedCount: appResult.movedCount + regularResult.movedCount + privilegedResult.movedCount,
            failed: appResult.failed + regularResult.failed + privilegedResult.failed + denied
        )
    }

    /// `/Applications/*.app` — PureMac AppFileTrasher: trashItem → Finder → admin.
    private static func uninstallAppBundles(
        _ items: [ScanItem],
        isCancelled: () -> Bool
    ) async -> CleanResult {
        guard !items.isEmpty else {
            return CleanResult(freedBytes: 0, movedCount: 0, failed: [])
        }
        if isCancelled() {
            return CleanResult(freedBytes: 0, movedCount: 0, failed: [])
        }
        let report = await AppUninstall.trashLikePureMac(items.map(\.url))
        return report.result
    }

    private static func moveRegularToTrash(
        _ items: [ScanItem],
        isCancelled: () -> Bool
    ) -> CleanResult {
        var freed: Int64 = 0
        var moved = 0
        var failed: [(URL, String)] = []
        let fm = FileManager.default

        for item in items {
            if isCancelled() { break }
            do {
                var resulting: NSURL?
                try fm.trashItem(at: item.url, resultingItemURL: &resulting)
                freed += item.byteCount
                moved += 1
            } catch {
                failed.append((item.url, error.localizedDescription))
            }
        }

        return CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
    }
}
