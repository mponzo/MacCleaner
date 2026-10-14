import Foundation

struct PurgeableReport: Sendable, Hashable {
    var totalBytes: Int64
    var freeBytes: Int64
    var availableImportantBytes: Int64
    var purgeableBytes: Int64

    var hasPurgeable: Bool { purgeableBytes > 1_048_576 }
}

enum PurgeableSpace {
    /// Estimates APFS purgeable space from volume capacity keys (macOS 11+).
    static func measure(volumeURL: URL = URL(fileURLWithPath: "/")) -> PurgeableReport {
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]
        let values = try? volumeURL.resourceValues(forKeys: keys)
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        let free = Int64(values?.volumeAvailableCapacity ?? 0)
        let important = Int64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        let opportunistic = values?.volumeAvailableCapacityForOpportunisticUsage.map { Int64($0) } ?? 0

        // Important capacity is usually higher than “free” when macOS holds purgeable files.
        let refined: Int64 = {
            if important > free { return important - free }
            if free > opportunistic && opportunistic > 0 { return free - opportunistic }
            return 0
        }()

        return PurgeableReport(
            totalBytes: total,
            freeBytes: free,
            availableImportantBytes: important,
            purgeableBytes: refined
        )
    }
}
