import AppKit
import Foundation

/// Reliable uninstall helpers for `.app` bundles (especially under `/Applications`).
enum AppUninstall {
    /// Quit a running copy of the app so trash/move can succeed.
    @MainActor
    static func quitIfRunning(bundleURL: URL, bundleID: String) async {
        let target = bundleURL.standardizedFileURL
        let apps = NSWorkspace.shared.runningApplications.filter {
            if let id = $0.bundleIdentifier, id == bundleID { return true }
            if let running = $0.bundleURL?.standardizedFileURL {
                return running == target
            }
            return false
        }
        guard !apps.isEmpty else { return }

        for app in apps {
            app.terminate()
        }
        try? await Task.sleep(nanoseconds: 800_000_000)
        for app in apps where !app.isTerminated {
            app.forceTerminate()
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
    }

    /// Move items to Trash using Finder/`NSWorkspace` (handles `/Applications` auth UI).
    static func recycleViaWorkspace(_ urls: [URL]) async -> CleanResult {
        guard !urls.isEmpty else {
            return CleanResult(freedBytes: 0, movedCount: 0, failed: [])
        }
        let sized = Dictionary(uniqueKeysWithValues: urls.map { ($0, DiskSizer.allocatedBytes(at: $0)) })

        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle(urls) { trashedMap, error in
                var freed: Int64 = 0
                var moved = 0
                var failed: [(URL, String)] = []

                for url in urls {
                    let trashed = trashedMap.keys.contains { $0.path == url.path }
                        || !FileManager.default.fileExists(atPath: url.path)
                    if trashed {
                        freed += sized[url] ?? 0
                        moved += 1
                    } else {
                        let message = error?.localizedDescription
                            ?? L10n.string("priv.remove_failed")
                        failed.append((url, message))
                    }
                }

                continuation.resume(
                    returning: CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
                )
            }
        }
    }

    /// Finder AppleScript fallback — often prompts for admin on `/Applications`.
    static func recycleViaFinder(_ urls: [URL]) async -> CleanResult {
        var freed: Int64 = 0
        var moved = 0
        var failed: [(URL, String)] = []

        for url in urls {
            let bytes = DiskSizer.allocatedBytes(at: url)
            let escaped = url.path
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
            let source = """
            tell application "Finder"
              move (POSIX file "\(escaped)" as alias) to trash
            end tell
            """
            let result = await runAppleScript(source)
            if result.success || !FileManager.default.fileExists(atPath: url.path) {
                if !FileManager.default.fileExists(atPath: url.path) {
                    freed += bytes
                    moved += 1
                } else {
                    failed.append((url, result.message.isEmpty ? L10n.string("priv.remove_failed") : result.message))
                }
            } else {
                failed.append((url, result.message.isEmpty ? L10n.string("priv.remove_failed") : result.message))
            }
        }

        return CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
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
