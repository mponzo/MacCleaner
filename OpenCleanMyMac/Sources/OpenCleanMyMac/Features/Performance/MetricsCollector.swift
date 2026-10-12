import Darwin
import Foundation

enum MetricsCollector {
    static func snapshot() -> SystemMetrics {
        let physical = ProcessInfo.processInfo.physicalMemory
        let vm = vmStatistics()
        let pageSize = UInt64(vm_kernel_page_size)

        let free = UInt64(vm.free_count) * pageSize
        let active = UInt64(vm.active_count) * pageSize
        let inactive = UInt64(vm.inactive_count) * pageSize
        let wired = UInt64(vm.wire_count) * pageSize
        let compressed = UInt64(vm.compressor_page_count) * pageSize
        let app = active + inactive
        let used = physical > free ? physical - free : active + inactive + wired

        let (diskTotal, diskFree) = diskUsage()
        let cpu = cpuLoad()

        return SystemMetrics(
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
            processCount: 0
        )
    }

    static func topProcesses(limit: Int = 12) -> [ProcessInfoRow] {
        listProcesses()
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(limit)
            .map { $0 }
    }

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

    private static func cpuLoad() -> Double {
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
        let user = Double(load.cpu_ticks.0)
        let system = Double(load.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return ((user + system + nice) / total) * 100
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

    private static func listProcesses() -> [ProcessInfoRow] {
        // libproc avoids spawning `ps`, which is often blocked for unsigned apps.
        let bytesNeeded = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytesNeeded > 0 else { return [] }
        let capacity = Int(bytesNeeded) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: capacity)
        let filled = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, bytesNeeded)
        }
        guard filled > 0 else { return [] }
        let pidCount = Int(filled) / MemoryLayout<pid_t>.size

        var rows: [ProcessInfoRow] = []
        rows.reserveCapacity(min(pidCount, 512))

        for index in 0..<pidCount {
            let pid = pids[index]
            guard pid > 0 else { continue }

            var info = proc_taskallinfo()
            let infoSize = Int32(MemoryLayout<proc_taskallinfo>.stride)
            let got = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(infoSize)) { raw in
                    proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, raw, infoSize)
                }
            }
            guard got == infoSize else { continue }

            let bsdName = withUnsafePointer(to: info.pbsd.pbi_name) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(2 * MAXCOMLEN)) { String(cString: $0) }
            }
            let commName = withUnsafePointer(to: info.pbsd.pbi_comm) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { String(cString: $0) }
            }
            let name = bsdName.isEmpty ? (commName.isEmpty ? "pid-\(pid)" : commName) : bsdName

            let memory = UInt64(info.ptinfo.pti_resident_size)
            rows.append(
                ProcessInfoRow(
                    id: pid,
                    pid: pid,
                    name: name,
                    memoryBytes: memory,
                    // Lifetime CPU time isn't a live %, leave 0; memory ranking is the primary signal.
                    cpuPercent: 0
                )
            )
        }
        return rows
    }
}
