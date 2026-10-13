import Foundation

/// Lightweight protection audit (PureMac Protection card — REA: FileVault / Gatekeeper strings).
enum ProtectionStatus {
    struct Snapshot: Sendable {
        var fileVaultOn: Bool?
        var gatekeeperOn: Bool?
    }

    static func snapshot() -> Snapshot {
        Snapshot(
            fileVaultOn: fileVaultEnabled(),
            gatekeeperOn: gatekeeperEnabled()
        )
    }

    private static func fileVaultEnabled() -> Bool? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
        process.arguments = ["status"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if text.localizedCaseInsensitiveContains("FileVault is On") { return true }
            if text.localizedCaseInsensitiveContains("FileVault is Off") { return false }
            return nil
        } catch {
            return nil
        }
    }

    private static func gatekeeperEnabled() -> Bool? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
        process.arguments = ["--status"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if text.localizedCaseInsensitiveContains("assessments enabled") { return true }
            if text.localizedCaseInsensitiveContains("disabled") { return false }
            return nil
        } catch {
            return nil
        }
    }
}
