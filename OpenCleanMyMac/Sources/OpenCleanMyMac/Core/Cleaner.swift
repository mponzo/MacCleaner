import Foundation

enum Cleaner {
    /// Moves selected items to Trash. System/allowlisted paths use the privileged admin bridge.
    /// User apps under `/Applications` try Finder trash first, then fall back to admin move.
    static func moveToTrash(
        _ items: [ScanItem],
        isCancelled: () -> Bool = { false }
    ) async -> CleanResult {
        let selected = items.filter { $0.isSelected && $0.category.isCleanable }

        var regular: [ScanItem] = []
        var privileged: [ScanItem] = []
        var denied: [(URL, String)] = []

        for item in selected {
            let url = item.url
            if !PrivilegedPathPolicy.needsPrivilege(for: url) {
                regular.append(item)
            } else if PrivilegedPathPolicy.isUserApplicationBundle(url) {
                // Prefer trash without an admin prompt when the user owns the app.
                regular.append(item)
            } else if PrivilegedPathPolicy.isRemovable(url) {
                privileged.append(item)
            } else {
                denied.append((url, L10n.string("priv.allowlist_denied")))
            }
        }

        var regularResult = moveRegularToTrash(regular, isCancelled: isCancelled)
        if isCancelled() {
            return CleanResult(
                freedBytes: regularResult.freedBytes,
                movedCount: regularResult.movedCount,
                failed: regularResult.failed + denied
            )
        }

        // Permission-denied app bundles → privileged move into Trash.
        var stillFailed: [(URL, String)] = []
        var retryItems: [ScanItem] = []
        for failure in regularResult.failed {
            if PrivilegedPathPolicy.isUserApplicationBundle(failure.0) {
                let bytes = regular.first(where: { $0.url == failure.0 })?.byteCount
                    ?? DiskSizer.allocatedBytes(at: failure.0)
                retryItems.append(
                    ScanItem(category: .appLeftovers, url: failure.0, byteCount: bytes, isSelected: true)
                )
            } else {
                stillFailed.append(failure)
            }
        }
        regularResult = CleanResult(
            freedBytes: regularResult.freedBytes,
            movedCount: regularResult.movedCount,
            failed: stillFailed
        )

        let privilegedURLs = privileged.map(\.url) + retryItems.map(\.url)
        let privilegedResult: CleanResult
        if privilegedURLs.isEmpty {
            privilegedResult = CleanResult(freedBytes: 0, movedCount: 0, failed: [])
        } else {
            privilegedResult = await PrivilegedBridge.removePaths(privilegedURLs)
        }

        return CleanResult(
            freedBytes: regularResult.freedBytes + privilegedResult.freedBytes,
            movedCount: regularResult.movedCount + privilegedResult.movedCount,
            failed: regularResult.failed + privilegedResult.failed + denied
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
