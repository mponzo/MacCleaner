import AppKit
import Foundation
import Observation

struct HomebrewCaskUpdate: Identifiable, Hashable, Sendable {
    var id: String { token }
    let token: String
    let name: String
    let installedVersions: [String]
    let currentVersion: String?
    var isBundleMissing: Bool
    var isSelected: Bool
}

@MainActor
@Observable
final class HomebrewCaskEngine {
    var casks: [HomebrewCaskUpdate] = []
    var isChecking = false
    var isUpgrading = false
    var brewPath: String?
    var progressLabel = L10n.string("brew.idle")
    var errorMessage: String?
    var lastMessage: String?
    var lastCheckedAt: Date?
    var operationProgress: Double?
    var operationDetail: String?

    private var workTask: Task<Void, Never>?

    var isBusy: Bool { isChecking || isUpgrading }
    var selectedCount: Int { casks.filter(\.isSelected).count }

    func refresh() {
        guard !isBusy else { return }
        workTask?.cancel()
        workTask = Task { await self.performRefresh() }
    }

    func upgradeSelected() {
        guard !isBusy, selectedCount > 0 else { return }
        workTask?.cancel()
        workTask = Task { await self.performUpgrade() }
    }

    func stop() {
        workTask?.cancel()
        workTask = nil
        if isChecking || isUpgrading {
            progressLabel = L10n.string("smartcare.stopped")
        }
        isChecking = false
        isUpgrading = false
        operationProgress = nil
        operationDetail = nil
    }

    func toggle(_ id: String) {
        guard let idx = casks.firstIndex(where: { $0.id == id }) else { return }
        casks[idx].isSelected.toggle()
    }

    func selectAll(_ selected: Bool) {
        for i in casks.indices { casks[i].isSelected = selected }
    }

    static func openAppStoreUpdates() {
        let candidates = [
            "macappstore://showUpdatesPage",
            "itms-apps://apps.apple.com/account/downloads"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.AppStore") {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func performRefresh() async {
        isChecking = true
        operationProgress = -1
        operationDetail = L10n.string("operation.cancel_safe")
        errorMessage = nil
        lastMessage = nil
        progressLabel = L10n.string("brew.checking")

        let resolved = Self.resolveBrewPath()
        brewPath = resolved
        guard let brew = resolved else {
            casks = []
            errorMessage = L10n.string("brew.not_found")
            progressLabel = L10n.string("brew.idle")
            isChecking = false
            operationProgress = nil
            operationDetail = nil
            return
        }

        do {
            let json = try await Self.run(brew, arguments: ["outdated", "--cask", "--json=v2"])
            if Task.isCancelled {
                isChecking = false
                operationProgress = nil
                operationDetail = nil
                progressLabel = L10n.string("smartcare.stopped")
                return
            }
            var parsed = try Self.parseOutdated(json)
            if !parsed.isEmpty {
                progressLabel = L10n.string("brew.enriching")
                parsed = await Self.enrichPresentations(parsed, brew: brew)
            }
            if Task.isCancelled {
                isChecking = false
                operationProgress = nil
                operationDetail = nil
                progressLabel = L10n.string("smartcare.stopped")
                return
            }
            casks = parsed
            lastCheckedAt = Date()
            progressLabel = parsed.isEmpty
                ? L10n.string("brew.up_to_date")
                : L10n.format("brew.summary", Int64(parsed.count))
        } catch {
            if !Task.isCancelled {
                casks = []
                errorMessage = error.localizedDescription
                progressLabel = L10n.string("brew.idle")
            }
        }
        isChecking = false
        operationProgress = nil
        operationDetail = nil
    }

    private func performUpgrade() async {
        let selected = casks.filter(\.isSelected)
        guard let brew = brewPath ?? Self.resolveBrewPath(), !selected.isEmpty else { return }
        isUpgrading = true
        errorMessage = nil
        lastMessage = nil
        var ok = 0
        var fail = 0
        let total = selected.count
        operationProgress = 0
        operationDetail = L10n.format("operation.step", Int64(0), Int64(total))

        for (index, cask) in selected.enumerated() {
            if Task.isCancelled { break }
            progressLabel = L10n.format("brew.upgrading", cask.name)
            do {
                _ = try await Self.run(brew, arguments: ["upgrade", "--cask", "--", cask.token])
                ok += 1
            } catch {
                fail += 1
            }
            let completed = index + 1
            operationProgress = Double(completed) / Double(total)
            operationDetail = L10n.format("operation.step", Int64(completed), Int64(total))
        }

        let wasCancelled = Task.isCancelled
        isUpgrading = false
        operationProgress = nil
        operationDetail = nil

        if wasCancelled {
            progressLabel = L10n.string("smartcare.stopped")
            await performRefresh()
            return
        }
        if fail == 0 {
            lastMessage = L10n.format("brew.upgraded", Int64(ok))
        } else {
            errorMessage = L10n.format("brew.upgrade_partial", Int64(ok), Int64(fail))
        }
        await performRefresh()
    }

    private static func resolveBrewPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "\(NSHomeDirectory())/homebrew/bin/brew"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    private static func run(_ brew: String, arguments: [String]) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brew)
                process.arguments = arguments
                var env = ProcessInfo.processInfo.environment
                env["HOMEBREW_NO_ANALYTICS"] = "1"
                env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
                process.environment = env
                let out = Pipe()
                let err = Pipe()
                process.standardOutput = out
                process.standardError = err
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = out.fileHandleForReading.readDataToEndOfFile()
                    let errText = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if process.terminationStatus != 0 {
                        continuation.resume(
                            throwing: NSError(
                                domain: "HomebrewCaskEngine",
                                code: Int(process.terminationStatus),
                                userInfo: [
                                    NSLocalizedDescriptionKey: errText.isEmpty
                                        ? L10n.string("brew.command_failed")
                                        : errText
                                ]
                            )
                        )
                        return
                    }
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func parseOutdated(_ data: Data) throws -> [HomebrewCaskUpdate] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "HomebrewCaskEngine",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L10n.string("brew.bad_json")]
            )
        }
        let list = (root["casks"] as? [[String: Any]]) ?? []
        return list.compactMap { row in
            let token = (row["token"] as? String)
                ?? (row["name"] as? String)
                ?? (row["name"] as? [String])?.first
            guard let token, !token.isEmpty else { return nil }
            let installed = (row["installed_versions"] as? [String]) ?? []
            let current = row["current_version"] as? String
            return HomebrewCaskUpdate(
                token: token,
                name: token,
                installedVersions: installed,
                currentVersion: current,
                isBundleMissing: false,
                isSelected: true
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func enrichPresentations(
        _ updates: [HomebrewCaskUpdate],
        brew: String
    ) async -> [HomebrewCaskUpdate] {
        let tokens = updates.map(\.token)
        guard !tokens.isEmpty else { return updates }
        var args = ["info", "--json=v2", "--cask", "--"]
        args.append(contentsOf: tokens)
        guard let data = try? await run(brew, arguments: args),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["casks"] as? [[String: Any]]
        else { return updates }

        var byToken: [String: (name: String, missing: Bool)] = [:]
        for row in list {
            guard let token = row["token"] as? String else { continue }
            let names = row["name"] as? [String] ?? []
            let display = names.first(where: { !$0.isEmpty }) ?? token
            let appPaths = Self.appBundlePaths(from: row)
            let missing = !appPaths.isEmpty && appPaths.allSatisfy { !FileManager.default.fileExists(atPath: $0) }
            byToken[token] = (display, missing)
        }

        return updates.map { item in
            guard let meta = byToken[item.token] else { return item }
            return HomebrewCaskUpdate(
                token: item.token,
                name: meta.name,
                installedVersions: item.installedVersions,
                currentVersion: item.currentVersion,
                isBundleMissing: meta.missing,
                isSelected: item.isSelected
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func appBundlePaths(from cask: [String: Any]) -> [String] {
        guard let artifacts = cask["artifacts"] as? [Any] else { return [] }
        var paths: [String] = []
        for artifact in artifacts {
            guard let dict = artifact as? [String: Any] else { continue }
            if let apps = dict["app"] as? [String] {
                for app in apps {
                    let name = (app as NSString).lastPathComponent
                    paths.append("/Applications/\(name)")
                }
            }
        }
        return paths
    }
}
