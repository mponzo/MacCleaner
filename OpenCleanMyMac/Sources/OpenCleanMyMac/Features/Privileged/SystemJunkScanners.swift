import Foundation

struct SystemCachesScanner: CategoryScanner {
    let category: ScanCategory = .systemCaches

    func scan() async -> [ScanItem] {
        let root = URL(fileURLWithPath: "/Library/Caches", isDirectory: true)
        return directoryChildren(at: root, category: category, minBytes: 2_000_000, limit: 60)
    }
}

struct SystemLogsScanner: CategoryScanner {
    let category: ScanCategory = .systemLogs

    func scan() async -> [ScanItem] {
        let roots = [
            URL(fileURLWithPath: "/Library/Logs", isDirectory: true),
            URL(fileURLWithPath: "/private/var/log", isDirectory: true)
        ]
        var items: [ScanItem] = []
        for root in roots {
            items.append(contentsOf: directoryChildren(at: root, category: category, minBytes: 512_000, limit: 40))
        }
        return items.sorted { $0.byteCount > $1.byteCount }.prefix(50).map { $0 }
    }
}

struct SystemLaunchAgentsScanner: CategoryScanner {
    let category: ScanCategory = .systemLaunchAgents

    func scan() async -> [ScanItem] {
        LaunchAgentScanner.scan()
            .filter { !$0.isUserDomain }
            .filter(\.isBroken)
            .map {
                ScanItem(
                    category: category,
                    url: $0.url,
                    byteCount: $0.byteCount,
                    displayName: $0.label,
                    isSelected: false // system agents default off
                )
            }
    }
}

private func directoryChildren(
    at root: URL,
    category: ScanCategory,
    minBytes: Int64,
    limit: Int
) -> [ScanItem] {
    guard FileManager.default.fileExists(atPath: root.path) else { return [] }
    guard let children = try? FileManager.default.contentsOfDirectory(
        at: root,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else {
        // Permission-denied roots still appear as a single opaque entry when readable size is 0.
        return []
    }

    return children.compactMap { url -> ScanItem? in
        guard PrivilegedPathPolicy.isRemovable(url) || url.path.hasPrefix(root.path + "/") else {
            return nil
        }
        // Skip obviously critical Apple system cache names.
        let name = url.lastPathComponent.lowercased()
        if name == "com.apple.birds" || name.hasPrefix("com.apple.spotlight") {
            return nil
        }
        let bytes = DiskSizer.allocatedBytes(at: url)
        guard bytes >= minBytes else { return nil }
        return ScanItem(
            category: category,
            url: url,
            byteCount: bytes,
            displayName: url.lastPathComponent,
            isSelected: false // privileged deletes require explicit selection
        )
    }
    .sorted { $0.byteCount > $1.byteCount }
    .prefix(limit)
    .map { $0 }
}
