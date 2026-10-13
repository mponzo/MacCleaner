import Foundation

enum Cleaner {
    /// Moves selected items to Trash. System/allowlisted paths use the privileged admin bridge.
    /// User apps under `/Applications` use Finder/`NSWorkspace`, then admin move as fallback.
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

        var appResult = await uninstallAppBundles(appBundles, isCancelled: isCancelled)
        if isCancelled() {
            return CleanResult(
                freedBytes: appResult.freedBytes,
                movedCount: appResult.movedCount,
                failed: appResult.failed + denied
            )
        }

        var regularResult = moveRegularToTrash(regular, isCancelled: isCancelled)
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

    /// `/Applications/*.app` often cannot use `FileManager.trashItem` without auth.
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

        let urls = items.map(\.url)
        var result = await AppUninstall.recycleViaWorkspace(urls)

        let stillThere = result.failed.map(\.0).filter { FileManager.default.fileExists(atPath: $0.path) }
        if !stillThere.isEmpty, !isCancelled() {
            let finder = await AppUninstall.recycleViaFinder(stillThere)
            result = merge(result.droppingFailures(stillThere), finder)
        }

        let afterFinder = result.failed.map(\.0).filter { FileManager.default.fileExists(atPath: $0.path) }
        if !afterFinder.isEmpty, !isCancelled() {
            let admin = await PrivilegedBridge.removePaths(afterFinder)
            result = merge(result.droppingFailures(afterFinder), admin)
        }

        // Ground truth: missing path = success (APIs sometimes error after a successful trash).
        var freed: Int64 = 0
        var moved = 0
        var failed: [(URL, String)] = []
        for item in items {
            if FileManager.default.fileExists(atPath: item.url.path) {
                let detail = result.failed.first(where: { $0.0.path == item.url.path })?.1
                    ?? L10n.string("priv.remove_failed")
                failed.append((item.url, detail))
            } else {
                freed += item.byteCount
                moved += 1
            }
        }
        return CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
    }

    private static func merge(_ a: CleanResult, _ b: CleanResult) -> CleanResult {
        CleanResult(
            freedBytes: a.freedBytes + b.freedBytes,
            movedCount: a.movedCount + b.movedCount,
            failed: a.failed + b.failed
        )
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

private extension CleanResult {
    func droppingFailures(_ urls: [URL]) -> CleanResult {
        let paths = Set(urls.map(\.path))
        return CleanResult(
            freedBytes: freedBytes,
            movedCount: movedCount,
            failed: failed.filter { !paths.contains($0.0.path) }
        )
    }
}
