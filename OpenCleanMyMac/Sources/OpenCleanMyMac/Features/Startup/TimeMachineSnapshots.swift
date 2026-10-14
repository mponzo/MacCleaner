import Foundation

struct TimeMachineSnapshot: Identifiable, Hashable, Sendable {
    var id: String { dateString }
    let dateString: String
    var isSelected: Bool
}

enum TimeMachineSnapshots {
    /// Local APFS snapshot date tokens from `tmutil listlocalsnapshotdates /`.
    static func listLocal() -> [TimeMachineSnapshot] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshotdates", "/"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        let text = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "Snapshot dates for volume group containing disk /:" }

        return lines.map { TimeMachineSnapshot(dateString: $0, isSelected: false) }
    }

    static func deleteLocal(_ dateString: String) async -> (ok: Bool, message: String) {
        let result = await PrivilegedBridge.runAdminShell(
            "/usr/bin/tmutil deletelocalsnapshots \(shellEscape(dateString))"
        )
        return (result.success, result.message)
    }

    private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
