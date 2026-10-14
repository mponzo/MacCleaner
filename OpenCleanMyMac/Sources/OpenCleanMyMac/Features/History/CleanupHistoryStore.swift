import Foundation
import Observation

enum CleanupHistorySource: String, Codable, CaseIterable, Sendable {
    case smartCare
    case scheduler
    case uninstaller
    case orphans
    case duplicates
    case developer
    case performance
    case startup

    var titleKey: String { "history.source.\(rawValue)" }

    var systemImage: String {
        switch self {
        case .smartCare: return "sparkles"
        case .scheduler: return "clock.arrow.circlepath"
        case .uninstaller: return "app.badge.checkmark"
        case .orphans: return "doc.text.magnifyingglass"
        case .duplicates: return "doc.on.doc"
        case .developer: return "hammer"
        case .performance: return "gauge.with.dots.needle.67percent"
        case .startup: return "power"
        }
    }
}

struct CleanupHistoryEntry: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var date: Date
    var source: CleanupHistorySource
    var freedBytes: Int64
    var movedCount: Int
    var failedCount: Int
    var detail: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        source: CleanupHistorySource,
        freedBytes: Int64,
        movedCount: Int,
        failedCount: Int,
        detail: String? = nil
    ) {
        self.id = id
        self.date = date
        self.source = source
        self.freedBytes = freedBytes
        self.movedCount = movedCount
        self.failedCount = failedCount
        self.detail = detail
    }
}

struct CleanupHistoryDayTotal: Identifiable, Sendable {
    var id: Date { day }
    var day: Date
    var freedBytes: Int64
}

/// Local-only log of successful cleanups for History + share card. Never leaves the Mac.
@MainActor
@Observable
final class CleanupHistoryStore {
    static let shared = CleanupHistoryStore()

    private enum Keys {
        static let entries = "cleanup.history.entries.v1"
    }

    private let maxEntries = 200

    private(set) var entries: [CleanupHistoryEntry] = []

    private init() {
        load()
    }

    var lifetimeFreedBytes: Int64 {
        entries.reduce(0) { $0 + $1.freedBytes }
    }

    var lifetimeMovedCount: Int {
        entries.reduce(0) { $0 + $1.movedCount }
    }

    func freedBytes(inLastDays days: Int) -> Int64 {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return entries.filter { $0.date >= start }.reduce(0) { $0 + $1.freedBytes }
    }

    /// Daily totals for the last `days` calendar days (including empty days as 0).
    func dailyTotals(lastDays days: Int = 14) -> [CleanupHistoryDayTotal] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var buckets: [Date: Int64] = [:]
        for offset in 0..<days {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                buckets[day] = 0
            }
        }
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            if buckets[day] != nil {
                buckets[day, default: 0] += entry.freedBytes
            }
        }
        return buckets.keys.sorted().map { CleanupHistoryDayTotal(day: $0, freedBytes: buckets[$0] ?? 0) }
    }

    func record(
        result: CleanResult,
        source: CleanupHistorySource,
        detail: String? = nil
    ) {
        guard result.movedCount > 0 || result.freedBytes > 0 else { return }
        let entry = CleanupHistoryEntry(
            source: source,
            freedBytes: result.freedBytes,
            movedCount: result.movedCount,
            failedCount: result.failed.count,
            detail: detail
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persist()
    }

    func clear() {
        entries = []
        persist()
    }

    func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Keys.entries) else { return }
        do {
            let decoded = try JSONDecoder().decode([CleanupHistoryEntry].self, from: data)
            entries = decoded.sorted { $0.date > $1.date }
        } catch {
            entries = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: Keys.entries)
        } catch {
            // Keep in-memory history if encode fails.
        }
    }
}
