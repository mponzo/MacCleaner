import Foundation

struct PrivilegedCommandResult: Sendable {
    let success: Bool
    let message: String
}

/// Admin bridge used until a signed SMAppService daemon is installed.
/// Supports FlushDNS, RemoveFile, ThinSnapshots, and launch-agent removal via allowlist.
enum PrivilegedBridge {
    static var isAvailable: Bool { true } // osascript admin prompt always available interactively

    static func statusSummary() -> String {
        L10n.string("priv.status_bridge")
    }

    static func flushDNS() async -> PrivilegedCommandResult {
        await runAdminShell("dscacheutil -flushcache; killall -HUP mDNSResponder")
    }

    static func thinLocalSnapshots() async -> PrivilegedCommandResult {
        await runAdminShell("tmutil thinlocalsnapshots / 10000000000 4")
    }

    static func removePaths(_ urls: [URL]) async -> CleanResult {
        var freed: Int64 = 0
        var moved = 0
        var failed: [(URL, String)] = []

        for url in urls {
            guard PrivilegedPathPolicy.isRemovable(url) else {
                failed.append((url, L10n.string("priv.allowlist_denied")))
                continue
            }
            let bytes = DiskSizer.allocatedBytes(at: url)
            let quoted = PrivilegedPathPolicy.shellQuoted(url.path)
            // Move into the user's Trash via admin so recovery remains possible.
            let trash = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".Trash", isDirectory: true)
            let destName = "OCMM-\(UUID().uuidString.prefix(8))-\(url.lastPathComponent)"
            let dest = trash.appendingPathComponent(destName)
            let destQuoted = PrivilegedPathPolicy.shellQuoted(dest.path)
            let trashQuoted = PrivilegedPathPolicy.shellQuoted(trash.path)

            // Bake the console username in — admin shells don't expand ~ to the GUI user.
            let owner = NSUserName()
            let script = """
            mkdir -p \(trashQuoted); mv \(quoted) \(destQuoted); chown -R \(owner) \(destQuoted) 2>/dev/null || true
            """
            let result = await runAdminShell(script)
            if result.success {
                freed += bytes
                moved += 1
            } else {
                failed.append((url, result.message.isEmpty ? L10n.string("priv.remove_failed") : result.message))
            }
        }

        return CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
    }

    static func runAdminShell(_ command: String) async -> PrivilegedCommandResult {
        // Escape for AppleScript string.
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        return await runAppleScript(source)
    }

    private static func runAppleScript(_ source: String) async -> PrivilegedCommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", source]
                let err = Pipe()
                process.standardOutput = Pipe()
                process.standardError = err
                do {
                    try process.run()
                    process.waitUntilExit()
                    let errText = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(
                        returning: PrivilegedCommandResult(
                            success: process.terminationStatus == 0,
                            message: errText
                        )
                    )
                } catch {
                    continuation.resume(
                        returning: PrivilegedCommandResult(success: false, message: error.localizedDescription)
                    )
                }
            }
        }
    }
}
