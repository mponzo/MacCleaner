import Foundation
import Observation

enum ScheduleInterval: String, CaseIterable, Identifiable, Codable, Sendable {
    case everyHour
    case every3Hours
    case every6Hours
    case every12Hours
    case daily
    case weekly
    case biweekly
    case monthly

    var id: String { rawValue }

    var titleKey: String { "sched.interval.\(rawValue)" }

    var seconds: TimeInterval {
        switch self {
        case .everyHour: return 3_600
        case .every3Hours: return 3_600 * 3
        case .every6Hours: return 3_600 * 6
        case .every12Hours: return 3_600 * 12
        case .daily: return 86_400
        case .weekly: return 86_400 * 7
        case .biweekly: return 86_400 * 14
        case .monthly: return 86_400 * 30
        }
    }
}

/// Background Smart Care runner (PureMac `SchedulerService` pattern via REA strings).
@MainActor
@Observable
final class CleanupScheduler {
    private enum Keys {
        static let enabled = "sched.enabled"
        static let interval = "sched.interval"
        static let autoClean = "sched.autoClean"
        static let thresholdMB = "sched.thresholdMB"
        static let lastRun = "sched.lastRun"
    }

    private(set) var isEnabled: Bool
    var interval: ScheduleInterval {
        didSet { persist(); reschedule() }
    }
    var autoCleanAfterScan: Bool {
        didSet { persist() }
    }
    /// Only auto-clean when reclaimable selection ≥ this many megabytes.
    var thresholdMB: Int {
        didSet { persist() }
    }
    private(set) var lastRunAt: Date?
    private(set) var nextRunAt: Date?
    private(set) var statusLabel = L10n.string("sched.idle")
    private(set) var isRunning = false

    private weak var engine: ScanEngine?
    private var loopTask: Task<Void, Never>?

    init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Keys.enabled)
        if let raw = defaults.string(forKey: Keys.interval),
           let value = ScheduleInterval(rawValue: raw) {
            interval = value
        } else {
            interval = .daily
        }
        autoCleanAfterScan = defaults.object(forKey: Keys.autoClean) as? Bool ?? false
        let storedThreshold = defaults.object(forKey: Keys.thresholdMB) as? Int
        thresholdMB = storedThreshold ?? 100
        lastRunAt = defaults.object(forKey: Keys.lastRun) as? Date
        refreshNextRun()
    }

    func attach(engine: ScanEngine) {
        self.engine = engine
        if isEnabled {
            start()
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        persist()
        if enabled {
            start()
        } else {
            stop()
            statusLabel = L10n.string("sched.disabled")
        }
    }

    func runNow() {
        guard !isRunning else { return }
        Task { await performCycle(force: true) }
    }

    private func start() {
        loopTask?.cancel()
        refreshNextRun()
        statusLabel = L10n.string("sched.enabled")
        loopTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s tick
                await self.tick()
            }
        }
    }

    private func stop() {
        loopTask?.cancel()
        loopTask = nil
        nextRunAt = nil
    }

    private func reschedule() {
        refreshNextRun()
        if isEnabled {
            start()
        }
    }

    private func refreshNextRun() {
        guard isEnabled else {
            nextRunAt = nil
            return
        }
        if let lastRunAt {
            nextRunAt = lastRunAt.addingTimeInterval(interval.seconds)
        } else {
            nextRunAt = Date().addingTimeInterval(interval.seconds)
        }
    }

    private func tick() async {
        guard isEnabled, !isRunning else { return }
        let due = nextRunAt ?? Date().addingTimeInterval(interval.seconds)
        guard Date() >= due else { return }
        await performCycle(force: false)
    }

    private func performCycle(force: Bool) async {
        guard let engine else {
            statusLabel = L10n.string("sched.no_engine")
            return
        }
        guard !engine.isBusy else {
            statusLabel = L10n.string("sched.busy")
            return
        }
        isRunning = true
        statusLabel = L10n.string("sched.running")
        engine.runSmartCare()
        try? await Task.sleep(nanoseconds: 150_000_000)
        while engine.isBusy {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled {
                isRunning = false
                return
            }
        }

        let reclaimable = engine.reclaimableBytes
        let thresholdBytes = Int64(thresholdMB) * 1_024 * 1_024
        if autoCleanAfterScan, reclaimable >= thresholdBytes, reclaimable > 0 {
            statusLabel = L10n.string("sched.cleaning")
            engine.cleanSelected(source: .scheduler)
            try? await Task.sleep(nanoseconds: 150_000_000)
            while engine.isBusy {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled {
                    isRunning = false
                    return
                }
            }
            statusLabel = L10n.format("sched.cleaned", ByteFormat.string(engine.lastCleanResult?.freedBytes ?? reclaimable))
        } else if force {
            statusLabel = L10n.format("sched.scanned", ByteFormat.string(reclaimable))
        } else if reclaimable < thresholdBytes {
            statusLabel = L10n.format("sched.below_threshold", ByteFormat.string(reclaimable), Int64(thresholdMB))
        } else {
            statusLabel = L10n.format("sched.scanned", ByteFormat.string(reclaimable))
        }

        lastRunAt = Date()
        UserDefaults.standard.set(lastRunAt, forKey: Keys.lastRun)
        refreshNextRun()
        isRunning = false
    }

    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: Keys.enabled)
        defaults.set(interval.rawValue, forKey: Keys.interval)
        defaults.set(autoCleanAfterScan, forKey: Keys.autoClean)
        defaults.set(thresholdMB, forKey: Keys.thresholdMB)
    }
}
