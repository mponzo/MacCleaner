import AppKit
import Foundation

enum AppInstallerError: LocalizedError {
    case notRunningFromBundle
    case copyFailed(String)
    case notInstalled

    var errorDescription: String? {
        switch self {
        case .notRunningFromBundle:
            return L10n.string("install.package_first")
        case .copyFailed(let detail):
            return L10n.format("install.failed", detail)
        case .notInstalled:
            return L10n.string("install.not_installed")
        }
    }
}

enum AppInstaller {
    static let appName = "MacCleaner.app"

    /// Prefer `/Applications` (Finder / Dock / Spotlight). Fall back to `~/Applications`.
    static var applicationsDirectory: URL {
        URL(fileURLWithPath: "/Applications", isDirectory: true)
    }

    static var homeApplicationsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
    }

    static var installedAppURL: URL {
        applicationsDirectory.appendingPathComponent(appName, isDirectory: true)
    }

    static var homeInstalledAppURL: URL {
        homeApplicationsDirectory.appendingPathComponent(appName, isDirectory: true)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installedAppURL.path)
            || FileManager.default.fileExists(atPath: homeInstalledAppURL.path)
    }

    /// Preferred install path when both exist: `/Applications`.
    static var preferredInstalledURL: URL? {
        if FileManager.default.fileExists(atPath: installedAppURL.path) {
            return installedAppURL
        }
        if FileManager.default.fileExists(atPath: homeInstalledAppURL.path) {
            return homeInstalledAppURL
        }
        return nil
    }

    /// Bundle currently running, if launched from a .app.
    static var runningBundleURL: URL? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app" else { return nil }
        return url
    }

    @discardableResult
    static func install() throws -> URL {
        guard let source = runningBundleURL else {
            throw AppInstallerError.notRunningFromBundle
        }
        return try install(from: source, revealInFinder: true)
    }

    /// Copies a `.app` bundle into `/Applications/MacCleaner.app` and removes any `~/Applications` copy.
    @discardableResult
    static func install(from source: URL, revealInFinder: Bool = false) throws -> URL {
        let fm = FileManager.default
        guard source.pathExtension == "app", fm.fileExists(atPath: source.path) else {
            throw AppInstallerError.copyFailed(L10n.string("updates.error.package"))
        }

        // Drop duplicate user-local install so Spotlight/Dock don't reopen an old build.
        if fm.fileExists(atPath: homeInstalledAppURL.path),
           homeInstalledAppURL.standardizedFileURL != source.standardizedFileURL {
            try? fm.removeItem(at: homeInstalledAppURL)
        }

        let destination = installedAppURL
        let runningFromDestination: Bool = {
            guard let running = runningBundleURL else { return false }
            return running.standardizedFileURL == destination.standardizedFileURL
        }()

        do {
            if runningFromDestination {
                let staging = applicationsDirectory.appendingPathComponent("MacCleaner.updating.app", isDirectory: true)
                if fm.fileExists(atPath: staging.path) {
                    try fm.removeItem(at: staging)
                }
                try ditto(from: source, to: staging)
                scheduleSwap(from: staging, to: destination)
            } else {
                if fm.fileExists(atPath: destination.path) {
                    try fm.removeItem(at: destination)
                }
                try ditto(from: source, to: destination)
            }
        } catch let error as AppInstallerError {
            throw error
        } catch {
            throw AppInstallerError.copyFailed(error.localizedDescription)
        }

        if revealInFinder {
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        }
        return destination
    }

    private static func ditto(from source: URL, to destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [source.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppInstallerError.copyFailed("ditto exit \(process.terminationStatus)")
        }
    }

    /// Replaces the installed app after this process exits (safe when updating in place).
    private static func scheduleSwap(from staging: URL, to destination: URL) {
        let script = """
        /bin/sleep 1
        /bin/rm -rf '\(destination.path)'
        /bin/mv '\(staging.path)' '\(destination.path)'
        /usr/bin/open -n '\(destination.path)'
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]
        try? process.run()
    }

    static func uninstall() throws {
        let fm = FileManager.default
        var removed = false
        for url in [installedAppURL, homeInstalledAppURL] where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
            removed = true
        }
        guard removed else { throw AppInstallerError.notInstalled }
    }

    static func openInstalledApp() {
        guard let url = preferredInstalledURL else { return }
        NSWorkspace.shared.open(url)
    }
}
