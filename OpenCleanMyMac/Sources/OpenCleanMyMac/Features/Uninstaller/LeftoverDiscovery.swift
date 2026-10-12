import Foundation

/// User-domain Library leftover paths keyed by bundle ID / app name.
enum LeftoverDiscovery {
    private static let ignoredBundlePrefixes = [
        "com.apple.",
        "com.apple.systempreferences",
        "edu.mit.Kerberos"
    ]

    static func isProtected(bundleID: String) -> Bool {
        ignoredBundlePrefixes.contains { bundleID.hasPrefix($0) }
            || bundleID == Bundle.main.bundleIdentifier
    }

    static func leftovers(forBundleID bundleID: String, appName: String) -> [AppLeftover] {
        guard !bundleID.isEmpty, !isProtected(bundleID: bundleID) else { return [] }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        var found: [AppLeftover] = []
        var seen = Set<String>()

        func append(kind: LeftoverKind, url: URL) {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return }
            guard FileManager.default.fileExists(atPath: path) else { return }
            seen.insert(path)
            let bytes = DiskSizer.allocatedBytes(at: url)
            guard bytes > 0 else { return }
            found.append(AppLeftover(kind: kind, url: url, byteCount: bytes))
        }

        // Exact bundle-ID paths (high confidence)
        append(kind: .preferences, url: library.appendingPathComponent("Preferences/\(bundleID).plist"))
        append(kind: .caches, url: library.appendingPathComponent("Caches/\(bundleID)", isDirectory: true))
        append(kind: .applicationSupport, url: library.appendingPathComponent("Application Support/\(bundleID)", isDirectory: true))
        append(kind: .logs, url: library.appendingPathComponent("Logs/\(bundleID)", isDirectory: true))
        append(kind: .savedState, url: library.appendingPathComponent("Saved Application State/\(bundleID).savedState", isDirectory: true))
        append(kind: .cookies, url: library.appendingPathComponent("Cookies/\(bundleID).binarycookies"))
        append(kind: .containers, url: library.appendingPathComponent("Containers/\(bundleID)", isDirectory: true))
        append(kind: .crashReporter, url: library.appendingPathComponent("Application Support/CrashReporter/\(bundleID)_\(appName).plist"))

        // Group containers often start with TEAMID.bundleID
        if let groupRoot = try? FileManager.default.contentsOfDirectory(
            at: library.appendingPathComponent("Group Containers", isDirectory: true),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in groupRoot where url.lastPathComponent.contains(bundleID) {
                append(kind: .groupContainers, url: url)
            }
        }

        // LaunchAgents matching bundle ID
        let agentRoots = [
            library.appendingPathComponent("LaunchAgents", isDirectory: true),
            URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true)
        ]
        for root in agentRoots {
            guard let agents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for agent in agents where agent.pathExtension == "plist"
                && agent.lastPathComponent.localizedCaseInsensitiveContains(bundleID) {
                append(kind: .launchAgents, url: agent)
            }
        }

        // Application Support / Caches folders named after the app (lower confidence)
        let safeName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        if safeName.count >= 3 {
            for (kind, relative) in [
                (LeftoverKind.applicationSupport, "Application Support"),
                (.caches, "Caches"),
                (.logs, "Logs")
            ] {
                let dir = library.appendingPathComponent(relative, isDirectory: true)
                guard let children = try? FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }
                for child in children {
                    let base = child.deletingPathExtension().lastPathComponent
                    if base.caseInsensitiveCompare(safeName) == .orderedSame
                        || base.localizedCaseInsensitiveContains(bundleID) {
                        append(kind: kind, url: child)
                    }
                }
            }

            // Preferences plists by app name
            let prefs = library.appendingPathComponent("Preferences", isDirectory: true)
            if let plists = try? FileManager.default.contentsOfDirectory(
                at: prefs,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                for plist in plists where plist.pathExtension == "plist" {
                    let base = plist.deletingPathExtension().lastPathComponent
                    if base.caseInsensitiveCompare(safeName) == .orderedSame
                        || base.localizedCaseInsensitiveContains(bundleID) {
                        append(kind: .preferences, url: plist)
                    }
                }
            }
        }

        return found.sorted { $0.byteCount > $1.byteCount }
    }

    /// Orphan leftovers: preference/caches/containers whose bundle ID is not installed.
    static func orphanLeftovers(installedBundleIDs: Set<String>) async -> [AppLeftover] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        var orphans: [AppLeftover] = []
        var seen = Set<String>()

        let probes: [(LeftoverKind, String, Bool)] = [
            (.preferences, "Preferences", false),
            (.caches, "Caches", true),
            (.containers, "Containers", true),
            (.savedState, "Saved Application State", true),
            (.applicationSupport, "Application Support", true)
        ]

        for (kind, relative, isDirectoryExpected) in probes {
            let root = library.appendingPathComponent(relative, isDirectory: true)
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children {
                let token: String
                if kind == .preferences {
                    guard child.pathExtension == "plist" else { continue }
                    token = child.deletingPathExtension().lastPathComponent
                } else if kind == .savedState {
                    guard child.pathExtension == "savedState"
                        || child.lastPathComponent.hasSuffix(".savedState") else { continue }
                    token = child.lastPathComponent.replacingOccurrences(of: ".savedState", with: "")
                } else {
                    token = child.lastPathComponent
                }

                guard token.contains(".") else { continue } // likely a reverse-DNS bundle id
                guard !isProtected(bundleID: token) else { continue }
                guard !installedBundleIDs.contains(token) else { continue }
                // Only treat as orphan if it looks like a full bundle id (vendor.app)
                let parts = token.split(separator: ".")
                guard parts.count >= 3 else { continue }

                let path = child.standardizedFileURL.path
                guard !seen.contains(path) else { continue }
                if isDirectoryExpected {
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
                        continue
                    }
                }

                let bytes = DiskSizer.allocatedBytes(at: child)
                guard bytes > 512_000 else { continue }
                seen.insert(path)
                orphans.append(AppLeftover(kind: kind, url: child, byteCount: bytes, isSelected: true))
            }
        }

        return orphans.sorted { $0.byteCount > $1.byteCount }
    }
}
