import Foundation

protocol CategoryScanner: Sendable {
    var category: ScanCategory { get }
    func scan() async -> [ScanItem]
}

enum ScannerRegistry {
    static var all: [any CategoryScanner] {
        [
            UserCachesScanner(),
            UserLogsScanner(),
            TrashScanner(),
            XcodeDerivedDataScanner(),
            XcodeArchivesScanner(),
            DeveloperCachesScanner(),
            DownloadsClutterScanner(),
            UnusedDiskImagesScanner(),
            BrowserCachesScanner(),
            AppLeftoversScanner(),
            BrokenLaunchAgentsScanner(),
            SystemCachesScanner(),
            SystemLogsScanner(),
            SystemLaunchAgentsScanner(),
            LargeHomeFoldersScanner()
        ]
    }
}

struct BrokenLaunchAgentsScanner: CategoryScanner {
    let category: ScanCategory = .brokenLaunchAgents

    func scan() async -> [ScanItem] {
        LaunchAgentScanner.scan()
            .filter { $0.isBroken && $0.isUserDomain }
            .map {
                ScanItem(
                    category: category,
                    url: $0.url,
                    byteCount: $0.byteCount,
                    displayName: $0.label,
                    isSelected: true
                )
            }
    }
}

struct AppLeftoversScanner: CategoryScanner {
    let category: ScanCategory = .appLeftovers

    func scan() async -> [ScanItem] {
        let apps = await ApplicationsCatalog.listInstalledApps()
        let ids = Set(apps.map(\.bundleIdentifier))
        let leftovers = await LeftoverDiscovery.orphanLeftovers(installedBundleIDs: ids)
        return leftovers.prefix(60).map {
            ScanItem(
                category: category,
                url: $0.url,
                byteCount: $0.byteCount,
                displayName: "\($0.kind.title): \($0.url.lastPathComponent)",
                isSelected: true
            )
        }
    }
}

struct UserCachesScanner: CategoryScanner {
    let category: ScanCategory = .userCaches

    func scan() async -> [ScanItem] {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches", isDirectory: true)
        return directoryChildren(at: root, category: category, minBytes: 1_048_576)
    }
}

struct UserLogsScanner: CategoryScanner {
    let category: ScanCategory = .userLogs

    func scan() async -> [ScanItem] {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        return directoryChildren(at: root, category: category, minBytes: 256_000)
    }
}

struct TrashScanner: CategoryScanner {
    let category: ScanCategory = .trash

    func scan() async -> [ScanItem] {
        let trash = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".Trash", isDirectory: true)
        let bytes = DiskSizer.allocatedBytes(at: trash)
        guard bytes > 0 else { return [] }
        return [ScanItem(category: category, url: trash, byteCount: bytes, displayName: "Trash")]
    }
}

struct XcodeDerivedDataScanner: CategoryScanner {
    let category: ScanCategory = .xcodeDerivedData

    func scan() async -> [ScanItem] {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData", isDirectory: true)
        return directoryChildren(at: root, category: category, minBytes: 1_048_576)
    }
}

struct XcodeArchivesScanner: CategoryScanner {
    let category: ScanCategory = .xcodeArchives

    func scan() async -> [ScanItem] {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/Archives", isDirectory: true)
        return directoryChildren(at: root, category: category, minBytes: 1_048_576)
    }
}

struct DeveloperCachesScanner: CategoryScanner {
    let category: ScanCategory = .developerCaches

    func scan() async -> [ScanItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [(String, String)] = [
            ("npm", ".npm/_cacache"),
            ("Homebrew", "Library/Caches/Homebrew"),
            ("pip", "Library/Caches/pip"),
            ("Gradle", ".gradle/caches"),
            ("CocoaPods", "Library/Caches/CocoaPods"),
            ("Yarn", "Library/Caches/Yarn"),
            ("pnpm", "Library/pnpm/store"),
            ("Cargo", ".cargo/registry/cache")
        ]

        return candidates.compactMap { name, relative in
            let url = home.appendingPathComponent(relative, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let bytes = DiskSizer.allocatedBytes(at: url)
            guard bytes > 1_048_576 else { return nil }
            return ScanItem(category: category, url: url, byteCount: bytes, displayName: name)
        }
    }
}

struct DownloadsClutterScanner: CategoryScanner {
    let category: ScanCategory = .downloadsClutter

    func scan() async -> [ScanItem] {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [
                .contentModificationDateKey, .isDirectoryKey
            ]) else { return nil }
            guard values.isDirectory != true else { return nil }
            guard let modified = values.contentModificationDate, modified < cutoff else { return nil }
            let bytes = DiskSizer.allocatedBytes(at: url)
            guard bytes > 5_242_880 else { return nil } // > 5 MB
            return ScanItem(category: category, url: url, byteCount: bytes)
        }
        .sorted { $0.byteCount > $1.byteCount }
        .prefix(40)
        .map { $0 }
    }
}

struct UnusedDiskImagesScanner: CategoryScanner {
    let category: ScanCategory = .unusedDiskImages

    func scan() async -> [ScanItem] {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let exts = Set(["dmg", "iso", "pkg", "zip"])
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { url in
            guard exts.contains(url.pathExtension.lowercased()) else { return nil }
            let bytes = DiskSizer.allocatedBytes(at: url)
            guard bytes > 1_048_576 else { return nil }
            return ScanItem(category: category, url: url, byteCount: bytes)
        }
        .sorted { $0.byteCount > $1.byteCount }
    }
}

struct BrowserCachesScanner: CategoryScanner {
    let category: ScanCategory = .browserCaches

    func scan() async -> [ScanItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let targets: [(String, String)] = [
            ("Safari Cache", "Library/Caches/com.apple.Safari"),
            ("Chrome Cache", "Library/Caches/Google/Chrome"),
            ("Firefox Cache", "Library/Caches/Firefox"),
            ("Edge Cache", "Library/Caches/com.microsoft.edgemac")
        ]

        return targets.compactMap { name, relative in
            let url = home.appendingPathComponent(relative, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let bytes = DiskSizer.allocatedBytes(at: url)
            guard bytes > 1_048_576 else { return nil }
            return ScanItem(category: category, url: url, byteCount: bytes, displayName: name, isSelected: false)
        }
    }
}

struct LargeHomeFoldersScanner: CategoryScanner {
    let category: ScanCategory = .largeHomeFolders

    func scan() async -> [ScanItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let folders = children.filter {
            ((try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory) == true
        }

        return folders.map { url in
            ScanItem(
                category: category,
                url: url,
                byteCount: DiskSizer.allocatedBytes(at: url),
                displayName: url.lastPathComponent,
                isSelected: false
            )
        }
        .filter { $0.byteCount > 50_000_000 }
        .sorted { $0.byteCount > $1.byteCount }
        .prefix(12)
        .map { $0 }
    }
}

private func directoryChildren(at root: URL, category: ScanCategory, minBytes: Int64) -> [ScanItem] {
    guard FileManager.default.fileExists(atPath: root.path) else { return [] }
    guard let children = try? FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else { return [] }

    return children.compactMap { url in
        let bytes = DiskSizer.allocatedBytes(at: url)
        guard bytes >= minBytes else { return nil }
        return ScanItem(category: category, url: url, byteCount: bytes)
    }
    .sorted { $0.byteCount > $1.byteCount }
    .prefix(80)
    .map { $0 }
}
