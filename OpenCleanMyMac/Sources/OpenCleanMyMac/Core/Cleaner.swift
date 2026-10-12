import Foundation

enum Cleaner {
    /// Moves selected items to Trash. System/allowlisted paths use the privileged admin bridge.
    static func moveToTrash(
        _ items: [ScanItem],
        isCancelled: () -> Bool = { false }
    ) async -> CleanResult {
        let selected = items.filter { $0.isSelected && $0.category.isCleanable }
        let privileged = selected.filter { PrivilegedPathPolicy.needsPrivilege(for: $0.url) }
        let regular = selected.filter { !PrivilegedPathPolicy.needsPrivilege(for: $0.url) }

        let regularResult = moveRegularToTrash(regular, isCancelled: isCancelled)
        if isCancelled() {
            return regularResult
        }

        let privilegedResult: CleanResult
        if privileged.isEmpty {
            privilegedResult = CleanResult(freedBytes: 0, movedCount: 0, failed: [])
        } else {
            privilegedResult = await PrivilegedBridge.removePaths(privileged.map(\.url))
        }

        return CleanResult(
            freedBytes: regularResult.freedBytes + privilegedResult.freedBytes,
            movedCount: regularResult.movedCount + privilegedResult.movedCount,
            failed: regularResult.failed + privilegedResult.failed
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
