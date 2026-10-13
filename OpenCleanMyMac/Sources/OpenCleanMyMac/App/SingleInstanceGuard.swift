import AppKit
import Foundation

/// Ensures only one interactive MacCleaner instance runs; activates the existing one otherwise.
enum SingleInstanceGuard {
    static let bundleID = "com.maccleaner.app"

    private static var retainedLock: FileHandle?

    /// Call before creating UI. If another instance is already running, activate it and exit.
    static func enforceOrExit() {
        if !acquireLock() {
            activateExistingInstance()
            Foundation.exit(0)
        }
        if let existing = findExistingInstance() {
            // Another process slipped through before we locked (rare); prefer the .app.
            if existing.bundleURL?.pathExtension == "app",
               Bundle.main.bundleURL.pathExtension != "app"
            {
                releaseLock()
                existing.activate()
                notifyActivate()
                Foundation.exit(0)
            }
        }
    }

    private static func acquireLock() -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacCleaner", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let lockURL = url.appendingPathComponent("instance.lock")
        if !FileManager.default.fileExists(atPath: lockURL.path) {
            FileManager.default.createFile(atPath: lockURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: lockURL) else { return false }
        let ok = flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0
        if ok {
            retainedLock = handle
            return true
        }
        handle.closeFile()
        return false
    }

    private static func releaseLock() {
        if let handle = retainedLock {
            flock(handle.fileDescriptor, LOCK_UN)
            handle.closeFile()
            retainedLock = nil
        }
    }

    private static func findExistingInstance() -> NSRunningApplication? {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let byBundle = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        var candidates = byBundle.filter { $0.processIdentifier != currentPID }

        if let ownID = Bundle.main.bundleIdentifier, ownID != bundleID {
            candidates += NSRunningApplication.runningApplications(withBundleIdentifier: ownID)
                .filter { $0.processIdentifier != currentPID }
        }

        if candidates.isEmpty {
            let name = ProcessInfo.processInfo.processName
            candidates = NSWorkspace.shared.runningApplications.filter {
                $0.processIdentifier != currentPID
                    && ($0.bundleIdentifier == bundleID
                        || $0.localizedName == "MacCleaner"
                        || $0.executableURL?.lastPathComponent == name)
            }
        }

        // Prefer /Applications so Dock/Spotlight don't keep an old ~/Applications instance alive.
        let preferred = candidates.first {
            ($0.bundleURL?.path ?? "").hasPrefix("/Applications/")
        }
        return preferred
            ?? candidates.first(where: { $0.bundleURL?.pathExtension == "app" })
            ?? candidates.first
    }

    private static func activateExistingInstance() {
        if let existing = findExistingInstance() {
            existing.activate()
        }
        notifyActivate()
    }

    private static func notifyActivate() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.maccleaner.activate"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
}
