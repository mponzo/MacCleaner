import Foundation

enum MaintenanceRunner {
    static func run(_ task: MaintenanceTaskID) async -> MaintenanceTaskResult {
        switch task {
        case .flushDNS:
            return await flushDNS()
        case .speedUpMail:
            return await speedUpMail()
        case .thinLocalSnapshots:
            return await thinLocalSnapshots()
        case .rebuildLaunchServices:
            return await rebuildLaunchServices()
        }
    }

    private static func flushDNS() async -> MaintenanceTaskResult {
        let result = await PrivilegedBridge.flushDNS()
        if result.success {
            return MaintenanceTaskResult(task: .flushDNS, success: true, message: L10n.string("maint.flushDNS.ok"))
        }
        return MaintenanceTaskResult(
            task: .flushDNS,
            success: false,
            message: result.message.isEmpty ? L10n.string("maint.flushDNS.fail") : result.message
        )
    }

    private static func speedUpMail() async -> MaintenanceTaskResult {
        // User-domain Mail Envelope Index vacuum (PerformanceService SpeedUpMail).
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Mail/V10/MailData/Envelope Index"),
            home.appendingPathComponent("Library/Mail/V9/MailData/Envelope Index"),
            home.appendingPathComponent("Library/Mail/V8/MailData/Envelope Index")
        ]
        guard let db = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return MaintenanceTaskResult(
                task: .speedUpMail,
                success: false,
                message: L10n.string("maint.speedUpMail.missing")
            )
        }

        let before = DiskSizer.allocatedBytes(at: db)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [db.path, "VACUUM;"]
        let err = Pipe()
        process.standardError = err
        process.standardOutput = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return MaintenanceTaskResult(task: .speedUpMail, success: false, message: error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return MaintenanceTaskResult(
                task: .speedUpMail,
                success: false,
                message: msg.isEmpty ? L10n.string("maint.speedUpMail.vacuum_fail") : msg
            )
        }
        let after = DiskSizer.allocatedBytes(at: db)
        let freed = max(0, before - after)
        return MaintenanceTaskResult(
            task: .speedUpMail,
            success: true,
            message: L10n.format("maint.speedUpMail.ok", ByteFormat.string(freed))
        )
    }

    private static func thinLocalSnapshots() async -> MaintenanceTaskResult {
        let result = await PrivilegedBridge.thinLocalSnapshots()
        if result.success {
            return MaintenanceTaskResult(
                task: .thinLocalSnapshots,
                success: true,
                message: L10n.string("maint.thinLocalSnapshots.ok")
            )
        }
        return MaintenanceTaskResult(
            task: .thinLocalSnapshots,
            success: false,
            message: result.message.isEmpty ? L10n.string("maint.thinLocalSnapshots.fail") : result.message
        )
    }

    private static func rebuildLaunchServices() async -> MaintenanceTaskResult {
        let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        guard FileManager.default.fileExists(atPath: lsregister) else {
            return MaintenanceTaskResult(
                task: .rebuildLaunchServices,
                success: false,
                message: L10n.string("maint.rebuildLaunchServices.missing")
            )
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: lsregister)
        process.arguments = ["-kill", "-r", "-domain", "local", "-domain", "user"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return MaintenanceTaskResult(
                task: .rebuildLaunchServices,
                success: false,
                message: error.localizedDescription
            )
        }
        return MaintenanceTaskResult(
            task: .rebuildLaunchServices,
            success: process.terminationStatus == 0,
            message: process.terminationStatus == 0
                ? L10n.string("maint.rebuildLaunchServices.ok")
                : L10n.format("maint.rebuildLaunchServices.fail_status", Int64(process.terminationStatus))
        )
    }
}
