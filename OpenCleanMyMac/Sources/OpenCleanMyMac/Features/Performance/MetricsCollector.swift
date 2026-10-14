import AppKit
import Darwin
import Foundation

/// Live host + process sampler. CPU percentages require consecutive samples (delta).
final class MetricsCollector: @unchecked Sendable {
    static let shared = MetricsCollector()

    private let lock = NSLock()
    private var previousBusy: UInt64 = 0
    private var previousTotal: UInt64 = 0
    private var previousProcessCPUNanos: [pid_t: UInt64] = [:]
    private var previousWall: CFAbsoluteTime = 0
    private var timebase = mach_timebase_info_data_t()
    private var timebaseReady = false

    private init() {}

    func snapshot(limit: Int? = 40) -> (SystemMetrics, [ProcessInfoRow]) {
        lock.lock()
        defer { lock.unlock() }

        ensureTimebase()
        let physical = ProcessInfo.processInfo.physicalMemory
        let vm = Self.vmStatistics()
        let pageSize = UInt64(vm_kernel_page_size)

        let free = UInt64(vm.free_count) * pageSize
        let active = UInt64(vm.active_count) * pageSize
        let inactive = UInt64(vm.inactive_count) * pageSize
        let wired = UInt64(vm.wire_count) * pageSize
        let compressed = UInt64(vm.compressor_page_count) * pageSize
        let app = active + inactive
        let used = physical > free ? physical - free : active + inactive + wired

        let (diskTotal, diskFree) = Self.diskUsage()
        let cpu = sampleHostCPULocked()
        let (processes, counted) = sampleProcessesLocked(limit: limit)

        let metrics = SystemMetrics(
            physicalMemoryBytes: physical,
            usedMemoryBytes: used,
            appMemoryBytes: app,
            wiredMemoryBytes: wired,
            compressedMemoryBytes: compressed,
            freeMemoryBytes: free,
            cpuLoadPercent: cpu,
            diskTotalBytes: diskTotal,
            diskFreeBytes: diskFree,
            uptimeSeconds: ProcessInfo.processInfo.systemUptime,
            processCount: counted
        )
        return (metrics, processes)
    }

    // MARK: - Host CPU

    private func sampleHostCPULocked() -> Double {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &load) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }

        let user = UInt64(load.cpu_ticks.0)
        let system = UInt64(load.cpu_ticks.1)
        let idle = UInt64(load.cpu_ticks.2)
        let nice = UInt64(load.cpu_ticks.3)
        let busy = user &+ system &+ nice
        let total = busy &+ idle

        defer {
            previousBusy = busy
            previousTotal = total
        }

        guard previousTotal != 0, total > previousTotal else { return 0 }
        let busyDelta = Double(busy &- previousBusy)
        let totalDelta = Double(total &- previousTotal)
        guard totalDelta > 0 else { return 0 }
        return min(100, max(0, (busyDelta / totalDelta) * 100))
    }

    // MARK: - Processes

    private func sampleProcessesLocked(limit: Int?) -> ([ProcessInfoRow], Int) {
        let now = CFAbsoluteTimeGetCurrent()
        let wallDelta = previousWall > 0 ? max(0.001, now - previousWall) : 0
        let cpuCores = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let myUID = getuid()

        let runningByPID = Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.compactMap {
                app -> (pid_t, NSRunningApplication)? in
                let pid = app.processIdentifier
                guard pid > 0 else { return nil }
                return (pid, app)
            }
        )

        let bytesNeeded = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytesNeeded > 0 else {
            previousWall = now
            previousProcessCPUNanos = [:]
            return ([], 0)
        }
        let capacity = Int(bytesNeeded) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: capacity)
        let filled = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, bytesNeeded)
        }
        guard filled > 0 else {
            previousWall = now
            previousProcessCPUNanos = [:]
            return ([], 0)
        }
        let pidCount = Int(filled) / MemoryLayout<pid_t>.size

        var rows: [ProcessInfoRow] = []
        rows.reserveCapacity(min(pidCount, 512))
        var nextCPU: [pid_t: UInt64] = [:]
        nextCPU.reserveCapacity(min(pidCount, 512))

        for index in 0..<pidCount {
            let pid = pids[index]
            guard pid > 1 else { continue }

            var info = proc_taskallinfo()
            let infoSize = Int32(MemoryLayout<proc_taskallinfo>.stride)
            let got = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(infoSize)) { raw in
                    proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, raw, infoSize)
                }
            }
            guard got == infoSize else { continue }

            let uid = info.pbsd.pbi_uid
            let running = runningByPID[pid]
            // Parity with PureMac: skip most system processes; keep user-owned + GUI apps.
            guard uid == myUID || running != nil else { continue }

            let bsdName = withUnsafePointer(to: info.pbsd.pbi_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(2 * MAXCOMLEN)) { String(cString: $0) }
            }
            let commName = withUnsafePointer(to: info.pbsd.pbi_comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { String(cString: $0) }
            }
            let fallbackName = bsdName.isEmpty ? (commName.isEmpty ? "pid-\(pid)" : commName) : bsdName
            let displayName = running?.localizedName?.nilIfEmpty ?? fallbackName

            let bundleID = running?.bundleIdentifier
            let bundleURL = running?.bundleURL
            let policy = running?.activationPolicy
            let isHelper = {
                if let policy, policy != .regular { return true }
                let lower = displayName.lowercased()
                if lower.contains("helper") || lower.contains("xpc") { return true }
                if let bundleID,
                   let main = runningByPID.values.first(where: {
                       $0.bundleIdentifier == bundleID && $0.activationPolicy == .regular
                   }),
                   main.processIdentifier != pid {
                    return true
                }
                return false
            }()

            let cpuTicks = UInt64(info.ptinfo.pti_total_user) &+ UInt64(info.ptinfo.pti_total_system)
            let cpuNanos = ticksToNanos(cpuTicks)
            nextCPU[pid] = cpuNanos

            var cpuPercent = 0.0
            if wallDelta > 0, let prev = previousProcessCPUNanos[pid], cpuNanos >= prev {
                let delta = Double(cpuNanos - prev)
                let capacityNanos = wallDelta * 1_000_000_000 * Double(cpuCores)
                if capacityNanos > 0 {
                    cpuPercent = min(100 * Double(cpuCores), max(0, (delta / capacityNanos) * 100))
                }
            }

            let memory = UInt64(info.ptinfo.pti_resident_size)
            rows.append(
                ProcessInfoRow(
                    id: pid,
                    pid: pid,
                    name: displayName,
                    memoryBytes: memory,
                    cpuPercent: cpuPercent,
                    bundleIdentifier: bundleID,
                    bundleURL: bundleURL,
                    isHelper: isHelper
                )
            )
        }

        previousProcessCPUNanos = nextCPU
        previousWall = now

        let sorted = rows.sorted { $0.memoryBytes > $1.memoryBytes }
        if let limit {
            return (Array(sorted.prefix(limit)), sorted.count)
        }
        return (sorted, sorted.count)
    }

    private func ensureTimebase() {
        guard !timebaseReady else { return }
        if mach_timebase_info(&timebase) == KERN_SUCCESS {
            timebaseReady = true
        }
    }

    private func ticksToNanos(_ ticks: UInt64) -> UInt64 {
        guard timebaseReady, timebase.denom != 0 else { return ticks }
        return ticks * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    // MARK: - Shared host helpers

    private static func vmStatistics() -> vm_statistics64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        if result != KERN_SUCCESS {
            return vm_statistics64()
        }
        return stats
    }

    private static func diskUsage() -> (Int64, Int64) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let values = try? home.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) else { return (0, 0) }
        let total = Int64(values.volumeTotalCapacity ?? 0)
        let free: Int64
        if let important = values.volumeAvailableCapacityForImportantUsage {
            free = important
        } else if let available = values.volumeAvailableCapacity {
            free = Int64(available)
        } else {
            free = 0
        }
        return (total, free)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
