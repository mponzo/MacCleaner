import Foundation
import Observation

struct HomebrewCaskUpdate: Identifiable, Hashable, Sendable {
    var id: String { token }
    let token: String
    let name: String
    let installedVersions: [String]
    let currentVersion: String?
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

    var selectedCount: Int { casks.filter(\.isSelected).count }

    func refresh() async {
        guard !isChecking, !isUpgrading else { return }
        isChecking = true
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
            return
        }

        do {
            let json = try await Self.run(brew, arguments: ["outdated", "--cask", "--json=v2"])
            let parsed = try Self.parseOutdated(json)
            casks = parsed
            progressLabel = parsed.isEmpty
                ? L10n.string("brew.up_to_date")
                : L10n.format("brew.summary", Int64(parsed.count))
        } catch {
            casks = []
            errorMessage = error.localizedDescription
            progressLabel = L10n.string("brew.idle")
        }
        isChecking = false
    }

    func toggle(_ id: String) {
        guard let idx = casks.firstIndex(where: { $0.id == id }) else { return }
        casks[idx].isSelected.toggle()
    }

    func selectAll(_ selected: Bool) {
        for i in casks.indices { casks[i].isSelected = selected }
    }

    func upgradeSelected() async {
        let selected = casks.filter(\.isSelected)
        guard let brew = brewPath ?? Self.resolveBrewPath(), !selected.isEmpty, !isUpgrading else { return }
        isUpgrading = true
        errorMessage = nil
        var ok = 0
        var fail = 0
        for cask in selected {
            progressLabel = L10n.format("brew.upgrading", cask.name)
            do {
                _ = try await Self.run(brew, arguments: ["upgrade", "--cask", cask.token])
                ok += 1
            } catch {
                fail += 1
            }
        }
        if fail == 0 {
            lastMessage = L10n.format("brew.upgraded", Int64(ok))
        } else {
            errorMessage = L10n.format("brew.upgrade_partial", Int64(ok), Int64(fail))
        }
        isUpgrading = false
        await refresh()
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
            let token = (row["name"] as? [String])?.first
                ?? (row["token"] as? String)
                ?? (row["name"] as? String)
            guard let token, !token.isEmpty else { return nil }
            let installed = (row["installed_versions"] as? [String]) ?? []
            let current = row["current_version"] as? String
            let display = (row["name"] as? [String])?.first ?? token
            return HomebrewCaskUpdate(
                token: token,
                name: display,
                installedVersions: installed,
                currentVersion: current,
                isSelected: true
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
