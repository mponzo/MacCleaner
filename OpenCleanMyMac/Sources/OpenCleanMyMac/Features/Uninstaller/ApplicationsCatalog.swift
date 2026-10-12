import AppKit
import Foundation

enum ApplicationsCatalog {
    static func listInstalledApps() async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) {
            enumerateApps()
        }.value
    }

    private static func enumerateApps() -> [InstalledApp] {
        let fm = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        var apps: [InstalledApp] = []
        var seenBundleIDs = Set<String>()

        for root in roots {
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                // Only top-level and one nested level of .app packages
                guard url.pathExtension == "app" else { continue }
                enumerator.skipDescendants()

                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      !bundleID.isEmpty
                else { continue }

                if seenBundleIDs.contains(bundleID) { continue }
                seenBundleIDs.insert(bundleID)

                let info = bundle.infoDictionary ?? [:]
                let name = (info["CFBundleDisplayName"] as? String)
                    ?? (info["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let version = (info["CFBundleShortVersionString"] as? String) ?? "—"
                let isSystem = url.path.hasPrefix("/System/")
                let protected = LeftoverDiscovery.isProtected(bundleID: bundleID) || isSystem
                let bytes = DiskSizer.allocatedBytes(at: url)

                apps.append(
                    InstalledApp(
                        name: name,
                        bundleIdentifier: bundleID,
                        version: version,
                        bundleURL: url,
                        byteCount: bytes,
                        isSystemApp: isSystem,
                        isProtected: protected,
                        leftovers: [],
                        includeAppBundle: !protected
                    )
                )
            }
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func enrichWithLeftovers(_ apps: [InstalledApp]) async -> [InstalledApp] {
        await withTaskGroup(of: InstalledApp.self) { group in
            for app in apps {
                group.addTask {
                    var copy = app
                    if !app.isProtected {
                        copy.leftovers = LeftoverDiscovery.leftovers(
                            forBundleID: app.bundleIdentifier,
                            appName: app.name
                        )
                    }
                    return copy
                }
            }
            var enriched: [InstalledApp] = []
            for await app in group {
                enriched.append(app)
            }
            return enriched.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }
}
