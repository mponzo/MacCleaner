import Foundation

struct SystemMetrics: Sendable, Hashable {
    var physicalMemoryBytes: UInt64
    var usedMemoryBytes: UInt64
    var appMemoryBytes: UInt64
    var wiredMemoryBytes: UInt64
    var compressedMemoryBytes: UInt64
    var freeMemoryBytes: UInt64
    var cpuLoadPercent: Double
    var diskTotalBytes: Int64
    var diskFreeBytes: Int64
    var uptimeSeconds: TimeInterval
    var processCount: Int // filled by process sampler when available

    var memoryUsedPercent: Double {
        guard physicalMemoryBytes > 0 else { return 0 }
        return Double(usedMemoryBytes) / Double(physicalMemoryBytes) * 100
    }

    var diskUsedPercent: Double {
        guard diskTotalBytes > 0 else { return 0 }
        return Double(diskTotalBytes - diskFreeBytes) / Double(diskTotalBytes) * 100
    }
}

struct ProcessInfoRow: Identifiable, Hashable, Sendable {
    let id: Int32
    let pid: Int32
    let name: String
    let memoryBytes: UInt64
    let cpuPercent: Double
}

struct LaunchAgentItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let label: String
    let url: URL
    let executablePath: String?
    let isBroken: Bool
    let isUserDomain: Bool
    let byteCount: Int64
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        label: String,
        url: URL,
        executablePath: String?,
        isBroken: Bool,
        isUserDomain: Bool,
        byteCount: Int64,
        isSelected: Bool = false
    ) {
        self.id = id
        self.label = label
        self.url = url
        self.executablePath = executablePath
        self.isBroken = isBroken
        self.isUserDomain = isUserDomain
        self.byteCount = byteCount
        self.isSelected = isSelected || isBroken
    }
}

enum MaintenanceTaskID: String, CaseIterable, Identifiable, Sendable {
    case flushDNS
    case speedUpMail
    case thinLocalSnapshots
    case rebuildLaunchServices

    var id: String { rawValue }

    var title: String {
        L10n.string(key: "maint.\(rawValue).title")
    }

    var detail: String {
        L10n.string(key: "maint.\(rawValue).detail")
    }

    var systemImage: String {
        switch self {
        case .flushDNS: return "network"
        case .speedUpMail: return "envelope"
        case .thinLocalSnapshots: return "externaldrive.badge.timemachine"
        case .rebuildLaunchServices: return "arrow.triangle.2.circlepath"
        }
    }

    var needsAdmin: Bool {
        switch self {
        case .flushDNS, .thinLocalSnapshots: return true
        case .speedUpMail, .rebuildLaunchServices: return false
        }
    }
}

struct MaintenanceTaskResult: Sendable {
    let task: MaintenanceTaskID
    let success: Bool
    let message: String
}
