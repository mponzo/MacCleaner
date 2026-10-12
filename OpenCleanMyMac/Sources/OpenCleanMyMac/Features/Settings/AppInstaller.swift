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

        let fm = FileManager.default
        try fm.createDirectory(at: applicationsDirectory, withIntermediateDirectories: true)

        let destination = installedAppURL
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }

        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            throw AppInstallerError.copyFailed(error.localizedDescription)
        }

        // Refresh Launch Services.
        NSWorkspace.shared.activateFileViewerSelecting([destination])
        return destination
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
