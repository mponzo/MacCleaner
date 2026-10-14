import Foundation
import Observation

struct DeveloperTarget: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let name: String
    let detailKey: String
    let url: URL
    let byteCount: Int64
    var isSelected: Bool

    var detail: String { L10n.string(key: detailKey) }
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
        let items = selected.map {
            ScanItem(
                category: .developerCaches,
                url: $0.url,
                byteCount: $0.byteCount,
                displayName: $0.name,
                isSelected: true
            )
        }
        let result = await Cleaner.moveToTrash(items)
        lastResult = result
        if !result.failed.isEmpty {
            errorMessage = L10n.format("smartcare.failed_count", Int64(result.failed.count))
        }
        isCleaning = false
        await refresh()
        if result.failed.isEmpty {
            progressLabel = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
        }
    }

    nonisolated static func discover() -> [DeveloperTarget] {
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
                name: name,
                detailKey: detailKey,
                url: url,
                byteCount: bytes,
                isSelected: false
            )
        }
        .sorted { $0.byteCount > $1.byteCount }
    }
}
