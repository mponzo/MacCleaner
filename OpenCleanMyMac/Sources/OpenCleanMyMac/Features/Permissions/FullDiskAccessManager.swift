import AppKit
import Foundation
import Observation

/// Probes Full Disk Access the way shipping cleaners do: try reading FDA-gated
/// Library locations. Inspired by PureMac's `FullDiskAccessManager` (REA strings).
@MainActor
@Observable
final class FullDiskAccessManager {
    static let shared = FullDiskAccessManager()

    private(set) var hasFullDiskAccess = false
    private(set) var isWatching = false

    private var watchTask: Task<Void, Never>?

    /// Paths that typically require Full Disk Access on modern macOS.
    private static let probeRelativePaths = [
        "Library/Safari/CloudTabs.db",
        "Library/Safari/Bookmarks.plist",
        "Library/Mail",
        "Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
        "Library/Application Support/com.apple.TCC/TCC.db"
    ]

    private init() {
        refresh()
    }

    func refresh() {
        hasFullDiskAccess = Self.probe()
    }

    static func probe() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        for relative in probeRelativePaths {
            let url = home.appendingPathComponent(relative)
            if fm.isReadableFile(atPath: url.path) {
                // TCC.db is especially strong signal when readable.
                if relative.hasSuffix("TCC.db") { return true }
                // Directory listing of Mail / Containers also indicates FDA.
                if relative == "Library/Mail" || relative.contains("Mail Downloads") {
                    if let _ = try? fm.contentsOfDirectory(atPath: url.path) {
                        return true
                    }
                }
                if relative.hasSuffix(".db") || relative.hasSuffix(".plist") {
                    if (try? Data(contentsOf: url, options: [.mappedIfSafe])) != nil {
                        return true
                    }
                }
            }
        }
        // Fallback: attempt to list ~/Library/Safari
        let safari = home.appendingPathComponent("Library/Safari")
        if let items = try? fm.contentsOfDirectory(atPath: safari.path), !items.isEmpty {
            return true
        }
        return false
    }

    func openSystemSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_AllFiles"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                break
            }
        }
        // Make the bundle easy to drag into the FDA list (PureMac pattern).
        let appURL = Bundle.main.bundleURL
        if appURL.pathExtension == "app" {
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
        }
    }

    /// Poll until FDA is granted or the caller stops watching.
    func startWatching(onGranted: @escaping () -> Void = {}) {
        watchTask?.cancel()
        isWatching = true
        watchTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.refresh()
                if self.hasFullDiskAccess {
                    self.isWatching = false
                    onGranted()
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            self?.isWatching = false
        }
    }

    func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
        isWatching = false
    }
}
