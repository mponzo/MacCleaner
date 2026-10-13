import AppKit
import Foundation

/// PureMac-style app file removal (`defaultAppFileTrasher` → admin pass).
/// 1) `FileManager.trashItem` (user Trash)
/// 2) Finder delete AppleEvent if still present
/// 3) Administrator move-to-Trash / remove for survivors (auth prompt)
enum AppUninstall {
    struct RemovalReport: Sendable {
        var result: CleanResult
        var needsFullDiskAccess: Bool
        var attemptedAdmin: Bool
    }

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

    /// Trash URLs the way PureMac's AppFileTrasher does, with admin fallback.
    static func trashLikePureMac(_ urls: [URL]) async -> RemovalReport {
        let unique = dedupe(urls)
        guard !unique.isEmpty else {
            return RemovalReport(
                result: CleanResult(freedBytes: 0, movedCount: 0, failed: []),
                needsFullDiskAccess: false,
                attemptedAdmin: false
            )
        }

        let sized = Dictionary(uniqueKeysWithValues: unique.map { ($0.path, DiskSizer.allocatedBytes(at: $0)) })
        var freed: Int64 = 0
        var moved = 0
        var failed: [(URL, String)] = []
        var survivors: [URL] = []
        var needsFDA = false

        // Pass 1 — trashItem (PureMac primary path)
        for url in unique {
            if !FileManager.default.fileExists(atPath: url.path) {
                freed += sized[url.path] ?? 0
                moved += 1
                continue
            }
            do {
                var resulting: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
                freed += sized[url.path] ?? 0
                moved += 1
            } catch {
                let ns = error as NSError
                if ns.domain == NSCocoaErrorDomain, ns.code == NSFileReadNoPermissionError {
                    needsFDA = true
                }
                if isPermissionError(error) {
                    survivors.append(url)
                } else if !FileManager.default.fileExists(atPath: url.path) {
                    freed += sized[url.path] ?? 0
                    moved += 1
                } else {
                    survivors.append(url)
                    failed.append((url, error.localizedDescription))
                }
            }
        }

        // Pass 2 — Finder delete (often surfaces the auth UI PureMac relies on)
        let afterTrash = survivors.filter { FileManager.default.fileExists(atPath: $0.path) }
        survivors = []
        failed = failed.filter { FileManager.default.fileExists(atPath: $0.0.path) }
        if !afterTrash.isEmpty {
            let finder = await recycleViaFinder(afterTrash)
            for url in afterTrash {
                if FileManager.default.fileExists(atPath: url.path) {
                    survivors.append(url)
                } else {
                    freed += sized[url.path] ?? 0
                    moved += 1
                    failed.removeAll { $0.0.path == url.path }
                }
            }
            // Keep finder error text for survivors when useful
            for (url, message) in finder.failed where FileManager.default.fileExists(atPath: url.path) {
                if !failed.contains(where: { $0.0.path == url.path }) {
                    failed.append((url, message))
                }
            }
        }

        // Pass 3 — administrator privileges (PureMac cleanWithAdminPrivileges)
        // Only escalate app bundles / allowlisted system leftovers — not FDA-locked ~/Library files.
        var attemptedAdmin = false
        let afterFinder = survivors.filter { FileManager.default.fileExists(atPath: $0.path) }
        let adminCandidates = afterFinder.filter { PrivilegedPathPolicy.isRemovable($0) }
        let fdaLocked = afterFinder.filter { !PrivilegedPathPolicy.isRemovable($0) }
        if !fdaLocked.isEmpty {
            needsFDA = true
            for url in fdaLocked {
                if !failed.contains(where: { $0.0.path == url.path }) {
                    failed.append((url, L10n.string("apps.fda_required_path")))
                }
            }
        }
        if !adminCandidates.isEmpty {
            attemptedAdmin = true
            let admin = await PrivilegedBridge.removePaths(adminCandidates)
            for url in adminCandidates {
                if FileManager.default.fileExists(atPath: url.path) {
                    let detail = admin.failed.first(where: { $0.0.path == url.path })?.1
                        ?? L10n.string("priv.remove_failed")
                    if let idx = failed.firstIndex(where: { $0.0.path == url.path }) {
                        failed[idx] = (url, detail)
                    } else {
                        failed.append((url, detail))
                    }
                } else {
                    freed += sized[url.path] ?? 0
                    moved += 1
                    failed.removeAll { $0.0.path == url.path }
                }
            }
        }

        // Ground truth
        var finalFailed: [(URL, String)] = []
        var finalFreed: Int64 = 0
        var finalMoved = 0
        for url in unique {
            if FileManager.default.fileExists(atPath: url.path) {
                let detail = failed.first(where: { $0.0.path == url.path })?.1
                    ?? L10n.string("priv.remove_failed")
                finalFailed.append((url, detail))
            } else {
                finalFreed += sized[url.path] ?? 0
                finalMoved += 1
            }
        }

        return RemovalReport(
            result: CleanResult(freedBytes: finalFreed, movedCount: finalMoved, failed: finalFailed),
            needsFullDiskAccess: needsFDA && !finalFailed.isEmpty,
            attemptedAdmin: attemptedAdmin
        )
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
            // `delete` = move to Trash in Finder (same family as PureMac's Finder path)
            let source = """
            tell application "Finder"
              delete (POSIX file "\(escaped)" as alias)
            end tell
            """
            let result = await runAppleScript(source)
            if !FileManager.default.fileExists(atPath: url.path) {
                freed += bytes
                moved += 1
            } else {
                failed.append((url, result.message.isEmpty ? L10n.string("priv.remove_failed") : result.message))
            }
        }

        return CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
    }

    private static func dedupe(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var out: [URL] = []
        for url in urls {
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { continue }
            out.append(url.standardizedFileURL)
        }
        return out
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain {
            switch ns.code {
            case NSFileWriteNoPermissionError,
                 NSFileReadNoPermissionError,
                 NSFileNoSuchFileError:
                return true
            default:
                break
            }
        }
        if ns.domain == NSPOSIXErrorDomain, ns.code == EACCES || ns.code == EPERM {
            return true
        }
        let text = error.localizedDescription.lowercased()
        return text.contains("permission") || text.contains("authorized") || text.contains("privileg")
    }

    private static func runAppleScript(_ source: String) async -> PrivilegedCommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Prefer NSAppleScript so Finder Automation prompts are tied to this app.
                var errorInfo: NSDictionary?
                if let script = NSAppleScript(source: source) {
                    _ = script.executeAndReturnError(&errorInfo)
                    let message = (errorInfo?[NSAppleScript.errorMessage] as? String) ?? ""
                    continuation.resume(
                        returning: PrivilegedCommandResult(success: errorInfo == nil, message: message)
                    )
                    return
                }

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
