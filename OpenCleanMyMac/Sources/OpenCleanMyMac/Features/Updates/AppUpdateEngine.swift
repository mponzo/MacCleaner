import AppKit
import Foundation
import Observation

struct RemoteAppRelease: Decodable, Sendable, Equatable {
    let version: String
    let build: Int
    let zipURL: URL
    let notes: String?
    let notesIT: String?

    enum CodingKeys: String, CodingKey {
        case version
        case build
        case zipURL = "zip_url"
        case notes
        case notesIT = "notes_it"
    }

    func localizedNotes(language: AppLanguage) -> String {
        let prefersItalian: Bool = {
            switch language {
            case .italian: return true
            case .english: return false
            case .system:
                return Locale.preferredLanguages.first?.hasPrefix("it") == true
            }
        }()
        if prefersItalian, let notesIT, !notesIT.isEmpty { return notesIT }
        return notes ?? ""
    }
}

enum AppUpdateError: LocalizedError {
    case invalidManifest
    case downloadFailed(String)
    case invalidPackage
    case installFailed(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidManifest:
            return L10n.string("updates.error.manifest")
        case .downloadFailed(let detail):
            return L10n.format("updates.error.download", detail)
        case .invalidPackage:
            return L10n.string("updates.error.package")
        case .installFailed(let detail):
            return L10n.format("updates.error.install", detail)
        case .network(let detail):
            return L10n.format("updates.error.network", detail)
        }
    }
}

@MainActor
@Observable
final class AppUpdateEngine {
    /// Manifest in the public MacCleaner repo (no telemetry — user-initiated GitHub fetch).
    static let manifestURL = URL(
        string: "https://raw.githubusercontent.com/mponzo/MacCleaner/main/releases/version.json"
    )!

    var isChecking = false
    var isUpdating = false
    var remote: RemoteAppRelease?
    var statusMessage: String?
    var errorMessage: String?
    var lastCheckedAt: Date?

    var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"
    }

    var installedBuild: Int {
        let raw = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0"
        return Int(raw) ?? 0
    }

    var updateAvailable: Bool {
        guard let remote else { return false }
        if remote.build != installedBuild {
            return remote.build > installedBuild
        }
        return compareVersions(remote.version, installedVersion) > 0
    }

    func checkForUpdates() async {
        guard !isChecking, !isUpdating else { return }
        isChecking = true
        errorMessage = nil
        statusMessage = L10n.string("updates.checking")
        defer { isChecking = false }

        do {
            var request = URLRequest(url: Self.manifestURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            request.setValue("MacCleaner/\(installedVersion)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw AppUpdateError.network("HTTP \(http.statusCode)")
            }

            let decoded = try JSONDecoder().decode(RemoteAppRelease.self, from: data)
            remote = decoded
            lastCheckedAt = Date()

            if updateAvailable {
                statusMessage = L10n.format("updates.available", decoded.version)
            } else {
                statusMessage = L10n.string("updates.up_to_date")
            }
        } catch let error as AppUpdateError {
            errorMessage = error.localizedDescription
            statusMessage = nil
        } catch {
            errorMessage = AppUpdateError.network(error.localizedDescription).localizedDescription
            statusMessage = nil
        }
    }

    func installUpdateAndRelaunch() async {
        guard let remote else {
            errorMessage = L10n.string("updates.error.check_first")
            return
        }
        guard updateAvailable else {
            statusMessage = L10n.string("updates.up_to_date")
            return
        }
        guard !isUpdating else { return }

        isUpdating = true
        errorMessage = nil
        statusMessage = L10n.string("updates.downloading")
        defer { isUpdating = false }

        let fm = FileManager.default
        let workRoot = fm.temporaryDirectory
            .appendingPathComponent("MacCleanerUpdate-\(UUID().uuidString)", isDirectory: true)

        do {
            try fm.createDirectory(at: workRoot, withIntermediateDirectories: true)
            let zipURL = workRoot.appendingPathComponent("MacCleaner.app.zip")

            var request = URLRequest(url: remote.zipURL)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 120
            request.setValue("MacCleaner/\(installedVersion)", forHTTPHeaderField: "User-Agent")

            let (tempFile, response) = try await URLSession.shared.download(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw AppUpdateError.downloadFailed("HTTP \(http.statusCode)")
            }
            if fm.fileExists(atPath: zipURL.path) {
                try fm.removeItem(at: zipURL)
            }
            try fm.moveItem(at: tempFile, to: zipURL)

            statusMessage = L10n.string("updates.installing")
            let extractDir = workRoot.appendingPathComponent("extract", isDirectory: true)
            try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
            try run("/usr/bin/ditto", args: ["-x", "-k", zipURL.path, extractDir.path])

            let newApp = try findAppBundle(in: extractDir)
            try validateAppBundle(newApp)

            try AppInstaller.install(from: newApp)

            statusMessage = L10n.string("updates.relaunching")
            // If we staged a live replace, AppInstaller already scheduled relaunch.
            // Otherwise open the installed copy after a short delay.
            if AppInstaller.runningBundleURL?.standardizedFileURL
                != AppInstaller.installedAppURL.standardizedFileURL
            {
                relaunchInstalledApp()
            } else {
                NSApp.terminate(nil)
            }
        } catch let error as AppUpdateError {
            errorMessage = error.localizedDescription
            statusMessage = nil
            try? fm.removeItem(at: workRoot)
        } catch {
            errorMessage = AppUpdateError.installFailed(error.localizedDescription).localizedDescription
            statusMessage = nil
            try? fm.removeItem(at: workRoot)
        }
    }

    // MARK: - Helpers

    private func compareVersions(_ lhs: String, _ rhs: String) -> Int {
        let a = lhs.split(separator: ".").compactMap { Int($0) }
        let b = rhs.split(separator: ".").compactMap { Int($0) }
        let count = max(a.count, b.count)
        for i in 0..<count {
            let left = i < a.count ? a[i] : 0
            let right = i < b.count ? b[i] : 0
            if left != right { return left < right ? -1 : 1 }
        }
        return 0
    }

    private func findAppBundle(in directory: URL) throws -> URL {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AppUpdateError.invalidPackage
        }
        for case let url as URL in enumerator {
            if url.pathExtension == "app" {
                return url
            }
        }
        throw AppUpdateError.invalidPackage
    }

    private func validateAppBundle(_ appURL: URL) throws {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard
            let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
            let bundleID = dict["CFBundleIdentifier"] as? String,
            bundleID == "com.maccleaner.app"
        else {
            throw AppUpdateError.invalidPackage
        }
    }

    private func run(_ launchPath: String, args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let err = Pipe()
        process.standardError = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw AppUpdateError.installFailed(message.isEmpty ? "exit \(process.terminationStatus)" : message)
        }
    }

    private func relaunchInstalledApp() {
        let appPath = AppInstaller.installedAppURL.path
        let script = """
        /bin/sleep 1
        /usr/bin/open '\(appPath)'
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", script]
        try? process.run()
        NSApp.terminate(nil)
    }
}
