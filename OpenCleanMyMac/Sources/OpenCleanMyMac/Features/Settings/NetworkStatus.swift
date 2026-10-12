import Foundation
import Network
#if canImport(CoreWLAN)
import CoreWLAN
#endif

struct NetworkRates: Sendable {
    var uploadBytesPerSec: Double
    var downloadBytesPerSec: Double
    var interfaceName: String
    var ssid: String?
    var isSatisfied: Bool
}

enum NetworkStatus {
    /// Cumulative interface counters (ibytes / obytes).
    static func interfaceCounters() -> (name: String, inBytes: UInt64, outBytes: UInt64)? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var bestName = "en0"
        var bestIn: UInt64 = 0
        var bestOut: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let name = String(cString: current.pointee.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("awdl") || name.hasPrefix("pdp_ip") else { continue }
            guard let data = current.pointee.ifa_data else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            let inn = UInt64(stats.ifi_ibytes)
            let out = UInt64(stats.ifi_obytes)
            if inn + out > bestIn + bestOut {
                bestName = name
                bestIn = inn
                bestOut = out
            }
        }
        return (bestName, bestIn, bestOut)
    }

    static func wifiSSID() -> String? {
        #if canImport(CoreWLAN)
        return CWWiFiClient.shared().interface()?.ssid()
        #else
        return nil
        #endif
    }

    static func pathSatisfied() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "maccleaner.path")
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: queue)
        }
    }

    static func sampleRates(interval: TimeInterval = 1.0) async -> NetworkRates {
        let a = interfaceCounters()
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        let b = interfaceCounters()
        let satisfied = await pathSatisfied()
        let ssid = wifiSSID()

        guard let a, let b, b.name == a.name else {
            return NetworkRates(
                uploadBytesPerSec: 0,
                downloadBytesPerSec: 0,
                interfaceName: a?.name ?? "en0",
                ssid: ssid,
                isSatisfied: satisfied
            )
        }
        let dt = max(interval, 0.001)
        let up = Double(b.outBytes &- a.outBytes) / dt
        let down = Double(b.inBytes &- a.inBytes) / dt
        return NetworkRates(
            uploadBytesPerSec: max(0, up),
            downloadBytesPerSec: max(0, down),
            interfaceName: b.name,
            ssid: ssid,
            isSatisfied: satisfied
        )
    }

    static func formatRate(_ bytesPerSec: Double) -> String {
        if bytesPerSec < 1024 {
            return String(format: "%.0f B/s", bytesPerSec)
        }
        if bytesPerSec < 1024 * 1024 {
            return String(format: "%.0f KB/s", bytesPerSec / 1024)
        }
        return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
    }
}
