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
            AIAppCachesScanner(),
            DownloadsClutterScanner(),
            UnusedDiskImagesScanner(),
            BrowserCachesScanner(),
            MailDownloadsScanner(),
            MailDataScanner(),
            LargeOldFilesScanner(),
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
            ("Cargo", ".cargo/registry/cache"),
            ("Core Simulator", "Library/Developer/CoreSimulator"),
            ("iOS Device Support", "Library/Developer/Xcode/iOS DeviceSupport"),
            ("Docker", "Library/Containers/com.docker.docker/Data")
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

/// Local LLM / AI tooling caches and models — never auto-selected.
struct AIAppCachesScanner: CategoryScanner {
    let category: ScanCategory = .aiAppCaches

    func scan() async -> [ScanItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates: [(String, String)] = [
            ("Ollama", ".ollama"),
            ("LM Studio cache", ".cache/lm-studio"),
            ("LM Studio", "Library/Application Support/LM Studio"),
            ("Hugging Face cache", ".cache/huggingface"),
            ("Diffusers cache", ".cache/huggingface/diffusers")
        ]
        return candidates.compactMap { name, relative in
            let url = home.appendingPathComponent(relative, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let bytes = DiskSizer.allocatedBytes(at: url)
            guard bytes > 1_048_576 else { return nil }
            return ScanItem(
                category: category,
                url: url,
                byteCount: bytes,
                displayName: name,
                isSelected: false
            )
        }
        .sorted { $0.byteCount > $1.byteCount }
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

struct MailDownloadsScanner: CategoryScanner {
    let category: ScanCategory = .mailDownloads

    func scan() async -> [ScanItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            home.appendingPathComponent(
                "Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
                isDirectory: true
            ),
            home.appendingPathComponent("Library/Mail Downloads", isDirectory: true)
        ]
        var items: [ScanItem] = []
        for root in roots {
            items.append(contentsOf: directoryChildren(at: root, category: category, minBytes: 256_000))
        }
        // Deduplicate by path
        var seen = Set<String>()
        return items.filter { seen.insert($0.url.path).inserted }
            .sorted { $0.byteCount > $1.byteCount }
            .prefix(80)
            .map { $0 }
    }
}

struct MailDataScanner: CategoryScanner {
    let category: ScanCategory = .mailData

    func scan() async -> [ScanItem] {
        let mailRoot = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mail", isDirectory: true)
        guard let versions = try? FileManager.default.contentsOfDirectory(
            at: mailRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var items: [ScanItem] = []
        for version in versions {
            let mailData = version.appendingPathComponent("MailData", isDirectory: true)
            guard FileManager.default.fileExists(atPath: mailData.path) else { continue }
            // Large envelope / index files — optional cleanup, off by default.
            let names = [
                "Envelope Index",
                "Envelope Index-shm",
                "Envelope Index-wal",
                "ExternalUpdates.storedata",
                "AvailableFeeds"
            ]
            for name in names {
                let url = mailData.appendingPathComponent(name)
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                let bytes = DiskSizer.allocatedBytes(at: url)
                guard bytes > 1_048_576 else { continue }
                items.append(
                    ScanItem(
                        category: category,
                        url: url,
                        byteCount: bytes,
                        displayName: "\(version.lastPathComponent)/\(name)"
                    )
                )
            }
            let bytes = DiskSizer.allocatedBytes(at: mailData)
            if bytes > 50_000_000 {
                items.append(
                    ScanItem(
                        category: category,
                        url: mailData,
                        byteCount: bytes,
                        displayName: "\(version.lastPathComponent) MailData"
                    )
                )
            }
        }
        var seen = Set<String>()
        return items.filter { seen.insert($0.url.path).inserted }
            .sorted { $0.byteCount > $1.byteCount }
    }
}

/// Files in Downloads / Documents / Desktop that are very large or very old.
/// Never auto-selected — review before Trash.
struct LargeOldFilesScanner: CategoryScanner {
    let category: ScanCategory = .largeOldFiles

    private static let largeBytes: Int64 = 100_000_000 // 100 MB
    private static let oldMinBytes: Int64 = 5_000_000 // avoid tiny old clutter
    private static let maxAgeDays: Double = 365
    private static let maxResults = 120
    private static let maxVisited = 25_000

    func scan() async -> [ScanItem] {
        let roots = Self.scanRoots()
        let cutoff = Date().addingTimeInterval(-Self.maxAgeDays * 24 * 60 * 60)
        let category = category

        return await Task.detached(priority: .utility) {
            var found: [ScanItem] = []
            var visited = 0
            let keys: Set<URLResourceKey> = [
                .isRegularFileKey,
                .isDirectoryKey,
                .isSymbolicLinkKey,
                .isPackageKey,
                .contentModificationDateKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey,
                .fileSizeKey
            ]

            for root in roots {
                guard FileManager.default.fileExists(atPath: root.path) else { continue }
                guard let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                while let node = enumerator.nextObject() {
                    guard let url = node as? URL else { continue }
                    if visited >= Self.maxVisited { break }
                    visited += 1

                    guard let values = try? url.resourceValues(forKeys: keys) else { continue }
                    if values.isSymbolicLink == true { continue }
                    if values.isDirectory == true { continue }
                    if values.isPackage == true { continue }
                    guard values.isRegularFile == true else { continue }

                    let bytes: Int64 = {
                        if let total = values.totalFileAllocatedSize { return Int64(total) }
                        if let allocated = values.fileAllocatedSize { return Int64(allocated) }
                        if let size = values.fileSize { return Int64(size) }
                        return 0
                    }()
                    guard bytes > 0 else { continue }

                    let isLarge = bytes >= Self.largeBytes
                    let isOld = (values.contentModificationDate.map { $0 < cutoff } ?? false)
                        && bytes >= Self.oldMinBytes
                    guard isLarge || isOld else { continue }

                    let folder = root.lastPathComponent
                    found.append(
                        ScanItem(
                            category: category,
                            url: url,
                            byteCount: bytes,
                            displayName: "\(folder)/\(url.lastPathComponent)",
                            isSelected: false
                        )
                    )
                }
            }

            var seen = Set<String>()
            return found
                .filter { seen.insert($0.url.path).inserted }
                .sorted { $0.byteCount > $1.byteCount }
                .prefix(Self.maxResults)
                .map { $0 }
        }.value
    }

    private static func scanRoots() -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var roots: [URL] = []
        if let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            roots.append(downloads)
        } else {
            roots.append(home.appendingPathComponent("Downloads", isDirectory: true))
        }
        if let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            roots.append(documents)
        } else {
            roots.append(home.appendingPathComponent("Documents", isDirectory: true))
        }
        if let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first {
            roots.append(desktop)
        } else {
            roots.append(home.appendingPathComponent("Desktop", isDirectory: true))
        }
        return roots
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
