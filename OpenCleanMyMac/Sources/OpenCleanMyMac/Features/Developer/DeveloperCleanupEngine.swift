import Foundation
import Observation

struct DeveloperTarget: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case folder(URL)
        /// Permanent delete via `xcrun simctl runtime delete`.
        case simulatorRuntime(identifier: String)
        /// Permanent prune via `docker builder prune -f` (no path).
        case dockerBuilderPrune
    }

    let id: String
    let name: String
    let detailKey: String
    let kind: Kind
    let byteCount: Int64
    var isSelected: Bool

    var detail: String { L10n.string(key: detailKey) }

    var revealURL: URL? {
        switch kind {
        case .folder(let url): return url
        case .simulatorRuntime, .dockerBuilderPrune: return nil
        }
    }

    var usesTrash: Bool {
        if case .folder = kind { return true }
        return false
    }
}

@MainActor
@Observable
final class DeveloperCleanupEngine {
    var targets: [DeveloperTarget] = []
    var isScanning = false
    var isCleaning = false
    var progressLabel = L10n.string("dev.idle")
    var lastResult: CleanResult?
    var errorMessage: String?

    var selectedBytes: Int64 {
        targets.filter(\.isSelected).reduce(0) { $0 + $1.byteCount }
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = nil
        progressLabel = L10n.string("dev.scanning")

        let found = await Task.detached(priority: .userInitiated) {
            Self.discover()
        }.value
        targets = found
        progressLabel = L10n.format(
            "dev.summary",
            Int64(found.count),
            ByteFormat.string(found.reduce(0) { $0 + $1.byteCount })
        )
        isScanning = false
    }

    func toggle(_ id: String) {
        guard let idx = targets.firstIndex(where: { $0.id == id }) else { return }
        targets[idx].isSelected.toggle()
    }

    func selectAll(_ selected: Bool) {
        for i in targets.indices {
            targets[i].isSelected = selected
        }
    }

    func cleanSelected() async {
        let selected = targets.filter(\.isSelected)
        guard !selected.isEmpty, !isCleaning else { return }
        isCleaning = true
        progressLabel = L10n.string("dev.cleaning")
        errorMessage = nil

        var freed: Int64 = 0
        var moved = 0
        var failed: [(URL, String)] = []

        let folders = selected.compactMap { target -> ScanItem? in
            guard case .folder(let url) = target.kind else { return nil }
            return ScanItem(
                category: .developerCaches,
                url: url,
                byteCount: target.byteCount,
                displayName: target.name,
                isSelected: true
            )
        }
        if !folders.isEmpty {
            let result = await Cleaner.moveToTrash(folders)
            freed += result.freedBytes
            moved += result.movedCount
            failed.append(contentsOf: result.failed)
        }

        for target in selected {
            switch target.kind {
            case .folder:
                continue
            case .simulatorRuntime(let identifier):
                progressLabel = L10n.format("dev.sim.delete", target.name)
                if Self.deleteSimulatorRuntime(identifier) {
                    freed += target.byteCount
                    moved += 1
                } else {
                    failed.append((
                        URL(fileURLWithPath: "/tmp/simctl-runtime-\(identifier)"),
                        L10n.string("dev.sim.delete_failed")
                    ))
                }
            case .dockerBuilderPrune:
                progressLabel = L10n.string("dev.docker.pruning")
                if Self.dockerBuilderPrune() {
                    freed += target.byteCount
                    moved += 1
                } else {
                    failed.append((
                        URL(fileURLWithPath: "/tmp/docker-builder-prune"),
                        L10n.string("dev.docker.prune_failed")
                    ))
                }
            }
        }

        let result = CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
        lastResult = result
        if !failed.isEmpty {
            errorMessage = L10n.format("smartcare.failed_count", Int64(failed.count))
        }
        isCleaning = false
        await refresh()
        if failed.isEmpty {
            progressLabel = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
        }
    }

    // MARK: - Discovery

    nonisolated static func discover() -> [DeveloperTarget] {
        var targets: [DeveloperTarget] = []
        targets.append(contentsOf: folderTargets())
        targets.append(contentsOf: simulatorRuntimeTargets())
        if let docker = dockerBuilderPruneTarget() {
            targets.append(docker)
        }
        return targets.sorted { $0.byteCount > $1.byteCount }
    }

    nonisolated private static func folderTargets() -> [DeveloperTarget] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [(String, String, String)] = [
            ("Xcode DerivedData", "dev.item.derived", "Library/Developer/Xcode/DerivedData"),
            ("Xcode Archives", "dev.item.archives", "Library/Developer/Xcode/Archives"),
            ("iOS Device Support", "dev.item.device_support", "Library/Developer/Xcode/iOS DeviceSupport"),
            ("watchOS Device Support", "dev.item.watch_support", "Library/Developer/Xcode/watchOS DeviceSupport"),
            ("Core Simulator", "dev.item.simulator", "Library/Developer/CoreSimulator"),
            ("Simulator Caches", "dev.item.sim_caches", "Library/Developer/CoreSimulator/Caches"),
            ("Docker data", "dev.item.docker", "Library/Containers/com.docker.docker/Data"),
            ("Docker Desktop", "dev.item.docker_desktop", "Library/Group Containers/group.com.docker"),
            ("Ollama models", "dev.item.ollama", ".ollama"),
            ("LM Studio", "dev.item.lmstudio", ".cache/lm-studio"),
            ("LM Studio data", "dev.item.lmstudio_data", "Library/Application Support/LM Studio"),
            ("npm cache", "dev.item.npm", ".npm/_cacache"),
            ("pnpm store", "dev.item.pnpm", "Library/pnpm/store"),
            ("Yarn cache", "dev.item.yarn", "Library/Caches/Yarn"),
            ("Homebrew cache", "dev.item.brew", "Library/Caches/Homebrew"),
            ("CocoaPods cache", "dev.item.pods", "Library/Caches/CocoaPods"),
            ("Gradle caches", "dev.item.gradle", ".gradle/caches"),
            ("pip cache", "dev.item.pip", "Library/Caches/pip"),
            ("Cargo registry", "dev.item.cargo", ".cargo/registry/cache")
        ]

        return candidates.compactMap { name, detailKey, relative in
            let url = home.appendingPathComponent(relative, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let bytes = DiskSizer.allocatedBytes(at: url)
            guard bytes > 1_048_576 else { return nil }
            return DeveloperTarget(
                id: "folder:\(url.path)",
                name: name,
                detailKey: detailKey,
                kind: .folder(url),
                byteCount: bytes,
                isSelected: false
            )
        }
    }

    /// Downloaded simulator runtimes via `simctl` (never auto-selected).
    nonisolated private static func simulatorRuntimeTargets() -> [DeveloperTarget] {
        guard let data = runCapture(
            "/usr/bin/xcrun",
            ["simctl", "runtime", "list", "-j"]
        ) ?? runCapture("/usr/bin/xcrun", ["simctl", "list", "runtimes", "-j"]) else {
            return []
        }
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return [] }

        var items: [(id: String, name: String, bytes: Int64)] = []

        if let dict = root as? [String: Any] {
            // runtime list -j often maps identifier → info
            for (key, value) in dict {
                guard let info = value as? [String: Any] else { continue }
                let identifier = (info["identifier"] as? String)
                    ?? (info["runtimeIdentifier"] as? String)
                    ?? key
                let name = (info["name"] as? String)
                    ?? (info["version"] as? String).map { "Simulator \($0)" }
                    ?? identifier
                let bytes = simulatorRuntimeBytes(info: info, identifier: identifier)
                guard bytes > 50_000_000 else { continue }
                // Skip built-in / bundled runtimes that cannot be deleted
                if let deletable = info["isAvailable"] as? Bool, !deletable { continue }
                items.append((identifier, name, bytes))
            }
        } else if let array = root as? [[String: Any]] {
            for info in array {
                guard let identifier = (info["identifier"] as? String)
                    ?? (info["runtimeIdentifier"] as? String) else { continue }
                let name = (info["name"] as? String) ?? identifier
                let bytes = simulatorRuntimeBytes(info: info, identifier: identifier)
                guard bytes > 50_000_000 else { continue }
                items.append((identifier, name, bytes))
            }
        }

        // Also measure on-disk .simruntime bundles (user Downloads of runtimes)
        let runtimeRoots = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Developer/CoreSimulator/Profiles/Runtimes", isDirectory: true),
            URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Profiles/Runtimes", isDirectory: true)
        ]
        var diskExtras: [DeveloperTarget] = []
        for root in runtimeRoots {
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for url in children where url.pathExtension == "simruntime" {
                let bytes = DiskSizer.allocatedBytes(at: url)
                guard bytes > 50_000_000 else { continue }
                let already = items.contains { $0.name == url.deletingPathExtension().lastPathComponent }
                if already { continue }
                diskExtras.append(
                    DeveloperTarget(
                        id: "folder:\(url.path)",
                        name: url.deletingPathExtension().lastPathComponent,
                        detailKey: "dev.item.sim_runtime_disk",
                        kind: .folder(url),
                        byteCount: bytes,
                        isSelected: false
                    )
                )
            }
        }

        let simctlTargets = items.map { item in
            DeveloperTarget(
                id: "simruntime:\(item.id)",
                name: item.name,
                detailKey: "dev.item.sim_runtime",
                kind: .simulatorRuntime(identifier: item.id),
                byteCount: item.bytes,
                isSelected: false
            )
        }
        return simctlTargets + diskExtras
    }

    nonisolated private static func simulatorRuntimeBytes(info: [String: Any], identifier: String) -> Int64 {
        if let size = info["sizeBytes"] as? Int64 { return size }
        if let size = info["sizeBytes"] as? Int { return Int64(size) }
        if let size = info["diskUsage"] as? Int64 { return size }
        // Fallback: known path patterns
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(
                "Library/Developer/CoreSimulator/Profiles/Runtimes/\(identifier).simruntime",
                isDirectory: true
            ),
            URL(fileURLWithPath: "/Library/Developer/CoreSimulator/Profiles/Runtimes/\(identifier).simruntime")
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            let bytes = DiskSizer.allocatedBytes(at: url)
            if bytes > 0 { return bytes }
        }
        // Unknown size but present — show a placeholder so user can still delete via simctl
        if info["isInternal"] as? Bool == true { return 0 }
        return 100_000_000
    }

    nonisolated private static func dockerBuilderPruneTarget() -> DeveloperTarget? {
        guard which("docker") != nil else { return nil }
        // Estimate reclaimable build cache; fail soft if daemon is down.
        guard let data = runCapture("/usr/local/bin/docker", ["system", "df", "-v"])
            ?? runCapture("/opt/homebrew/bin/docker", ["system", "df", "-v"])
            ?? runCapture("/usr/bin/env", ["docker", "system", "df", "--format", "{{json .}}"])
        else { return nil }

        let text = String(data: data, encoding: .utf8) ?? ""
        let reclaimable = parseDockerReclaimableBytes(text)
        guard reclaimable > 50_000_000 else { return nil }
        return DeveloperTarget(
            id: "docker:builder-prune",
            name: "Docker build cache",
            detailKey: "dev.item.docker_builder",
            kind: .dockerBuilderPrune,
            byteCount: reclaimable,
            isSelected: false
        )
    }

    nonisolated private static func parseDockerReclaimableBytes(_ text: String) -> Int64 {
        // Look for lines like "Build Cache … 12.3GB … 4.5GB"
        // or TYPE SIZE RECLAIMABLE
        var best: Int64 = 0
        for line in text.split(whereSeparator: \.isNewline) {
            let lower = line.lowercased()
            guard lower.contains("build cache") || lower.contains("build-cache") else { continue }
            let numbers = extractDockerSizes(String(line))
            if let last = numbers.last {
                best = max(best, last)
            }
        }
        if best == 0 {
            // Fallback: total reclaimable mentioned anywhere
            for line in text.split(whereSeparator: \.isNewline) where line.lowercased().contains("reclaimable") {
                if let n = extractDockerSizes(String(line)).last {
                    best = max(best, n)
                }
            }
        }
        return best
    }

    nonisolated private static func extractDockerSizes(_ line: String) -> [Int64] {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*([KMGT]i?B)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        let ns = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { match -> Int64? in
            guard match.numberOfRanges == 3,
                  let value = Double(ns.substring(with: match.range(at: 1))) else { return nil }
            let unit = ns.substring(with: match.range(at: 2)).uppercased()
            let mult: Double
            switch unit {
            case "KB", "KIB": mult = 1_000
            case "MB", "MIB": mult = 1_000_000
            case "GB", "GIB": mult = 1_000_000_000
            case "TB", "TIB": mult = 1_000_000_000_000
            default: mult = 1
            }
            return Int64(value * mult)
        }
    }

    nonisolated private static func deleteSimulatorRuntime(_ identifier: String) -> Bool {
        runStatus("/usr/bin/xcrun", ["simctl", "runtime", "delete", identifier]) == 0
    }

    nonisolated private static func dockerBuilderPrune() -> Bool {
        if which("docker") == nil { return false }
        if runStatus("/usr/bin/env", ["docker", "builder", "prune", "-f"]) == 0 { return true }
        if runStatus("/opt/homebrew/bin/docker", ["builder", "prune", "-f"]) == 0 { return true }
        return runStatus("/usr/local/bin/docker", ["builder", "prune", "-f"]) == 0
    }

    nonisolated private static func which(_ name: String) -> String? {
        guard let data = runCapture("/usr/bin/which", [name]),
              let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return nil }
        return path
    }

    nonisolated private static func runCapture(_ launchPath: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        return out.fileHandleForReading.readDataToEndOfFile()
    }

    nonisolated private static func runStatus(_ launchPath: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
