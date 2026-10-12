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

    static var applicationsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
    }

    static var installedAppURL: URL {
        applicationsDirectory.appendingPathComponent(appName, isDirectory: true)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: installedAppURL.path)
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

    /// Copies a `.app` bundle into `~/Applications/MacCleaner.app`.
    @discardableResult
    static func install(from source: URL, revealInFinder: Bool = false) throws -> URL {
        let fm = FileManager.default
        guard source.pathExtension == "app", fm.fileExists(atPath: source.path) else {
            throw AppInstallerError.copyFailed(L10n.string("updates.error.package"))
        }

        try fm.createDirectory(at: applicationsDirectory, withIntermediateDirectories: true)

        let destination = installedAppURL
        let runningFromDestination: Bool = {
            guard let running = runningBundleURL else { return false }
            return running.standardizedFileURL == destination.standardizedFileURL
        }()

        do {
            if runningFromDestination {
                // Stage beside the live app; relaunch script swaps after quit.
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
        /usr/bin/open '\(destination.path)'
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]
        try? process.run()
    }

    static func uninstall() throws {
        guard isInstalled else { throw AppInstallerError.notInstalled }
        try FileManager.default.removeItem(at: installedAppURL)
    }

    static func openInstalledApp() {
        guard isInstalled else { return }
        NSWorkspace.shared.open(installedAppURL)
    }
}
