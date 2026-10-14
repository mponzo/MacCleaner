import Foundation
import Security

/// How aggressively to match Library leftovers for an app.
enum LeftoverMatchSensitivity: String, CaseIterable, Identifiable, Sendable {
    case strict
    case enhanced
    case deep

    var id: String { rawValue }

    var title: String {
        L10n.string(key: "apps.sensitivity.\(rawValue)")
    }

    var detail: String {
        L10n.string(key: "apps.sensitivity.\(rawValue).detail")
    }
}

/// Identity hints used by the leftover matcher.
struct AppIdentity: Sendable {
    let bundleID: String
    let appName: String
    let teamID: String?
    let bundleURL: URL?

    /// Vendor prefix such as `com.company` from `com.company.app`.
    var vendorPrefix: String? {
        let parts = bundleID.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        return parts.prefix(2).joined(separator: ".")
    }

    static func from(bundleURL: URL) -> AppIdentity {
        let bundle = Bundle(url: bundleURL)
        let info = bundle?.infoDictionary ?? [:]
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier
            ?? (info["CFBundleIdentifier"] as? String)
            ?? "unknown.\(bundleURL.lastPathComponent)"
        return AppIdentity(
            bundleID: bundleID,
            appName: name,
            teamID: teamIdentifier(for: bundleURL),
            bundleURL: bundleURL
        )
    }

    static func teamIdentifier(for bundleURL: URL) -> String? {
        var staticCode: SecStaticCode?
        let create = SecStaticCodeCreateWithPath(bundleURL as CFURL, [], &staticCode)
        guard create == errSecSuccess, let staticCode else { return nil }
        var info: CFDictionary?
        let copy = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &info
        )
        guard copy == errSecSuccess, let info = info as? [String: Any] else { return nil }
        if let team = info[kSecCodeInfoTeamIdentifier as String] as? String, !team.isEmpty {
            return team
        }
        return nil
    }
}

/// User-domain Library leftover paths keyed by bundle ID / app name / team ID.
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

    static func leftovers(
        forBundleID bundleID: String,
        appName: String,
        bundleURL: URL? = nil,
        sensitivity: LeftoverMatchSensitivity = .enhanced
    ) -> [AppLeftover] {
        let identity = AppIdentity(
            bundleID: bundleID,
            appName: appName,
            teamID: bundleURL.flatMap(AppIdentity.teamIdentifier(for:)),
            bundleURL: bundleURL
        )
        return leftovers(for: identity, sensitivity: sensitivity)
    }

    static func leftovers(
        for identity: AppIdentity,
        sensitivity: LeftoverMatchSensitivity = .enhanced
    ) -> [AppLeftover] {
        guard !identity.bundleID.isEmpty, !isProtected(bundleID: identity.bundleID) else { return [] }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        var found: [AppLeftover] = []
        var seen = Set<String>()

        func append(kind: LeftoverKind, url: URL) {
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return }
            guard FileManager.default.fileExists(atPath: path) else { return }
            // Never propose removing the app bundle itself via leftovers.
            if let bundlePath = identity.bundleURL?.standardizedFileURL.path, path == bundlePath {
                return
            }
            seen.insert(path)
            let bytes = DiskSizer.allocatedBytes(at: url)
            guard bytes > 0 else { return }
            found.append(AppLeftover(kind: kind, url: url, byteCount: bytes))
        }

        // MARK: Strict — exact reverse-DNS paths
        append(kind: .preferences, url: library.appendingPathComponent("Preferences/\(identity.bundleID).plist"))
        append(kind: .caches, url: library.appendingPathComponent("Caches/\(identity.bundleID)", isDirectory: true))
        append(kind: .applicationSupport, url: library.appendingPathComponent("Application Support/\(identity.bundleID)", isDirectory: true))
        append(kind: .logs, url: library.appendingPathComponent("Logs/\(identity.bundleID)", isDirectory: true))
        append(
            kind: .savedState,
            url: library.appendingPathComponent(
                "Saved Application State/\(identity.bundleID).savedState",
                isDirectory: true
            )
        )
        append(kind: .cookies, url: library.appendingPathComponent("Cookies/\(identity.bundleID).binarycookies"))
        append(kind: .containers, url: library.appendingPathComponent("Containers/\(identity.bundleID)", isDirectory: true))
        append(
            kind: .crashReporter,
            url: library.appendingPathComponent(
                "Application Support/CrashReporter/\(identity.bundleID)_\(identity.appName).plist"
            )
        )
        append(
            kind: .applicationSupport,
            url: library.appendingPathComponent("HTTPStorages/\(identity.bundleID)", isDirectory: true)
        )
        append(
            kind: .applicationSupport,
            url: library.appendingPathComponent("WebKit/\(identity.bundleID)", isDirectory: true)
        )
        append(
            kind: .applicationSupport,
            url: library.appendingPathComponent("Application Scripts/\(identity.bundleID)", isDirectory: true)
        )

        // Group containers: full bundle ID substring (common: TEAMID.bundleID)
        if let groupRoot = try? FileManager.default.contentsOfDirectory(
            at: library.appendingPathComponent("Group Containers", isDirectory: true),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for url in groupRoot where url.lastPathComponent.contains(identity.bundleID) {
                append(kind: .groupContainers, url: url)
            }
            if sensitivity != .strict, let team = identity.teamID, team.count >= 8 {
                for url in groupRoot where url.lastPathComponent.hasPrefix("\(team).") {
                    append(kind: .groupContainers, url: url)
                }
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
                && agent.lastPathComponent.localizedCaseInsensitiveContains(identity.bundleID) {
                append(kind: .launchAgents, url: agent)
            }
        }

        guard sensitivity != .strict else {
            return found.sorted { $0.byteCount > $1.byteCount }
        }

        // MARK: Enhanced — name / vendor folder heuristics
        let safeName = identity.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameTokens = normalizedNameTokens(safeName)
        let vendor = identity.vendorPrefix

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
                if matchesEnhanced(base: base, identity: identity, nameTokens: nameTokens, vendor: vendor) {
                    append(kind: kind, url: child)
                }
            }
        }

        let prefs = library.appendingPathComponent("Preferences", isDirectory: true)
        if let plists = try? FileManager.default.contentsOfDirectory(
            at: prefs,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for plist in plists where plist.pathExtension == "plist" {
                let base = plist.deletingPathExtension().lastPathComponent
                if matchesEnhanced(base: base, identity: identity, nameTokens: nameTokens, vendor: vendor) {
                    append(kind: .preferences, url: plist)
                }
            }
        }

        // Containers whose id equals or ends with .bundleID (rare variants)
        if let containers = try? FileManager.default.contentsOfDirectory(
            at: library.appendingPathComponent("Containers", isDirectory: true),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            for child in containers {
                let base = child.lastPathComponent
                if base == identity.bundleID || base.hasSuffix(".\(identity.bundleID)") {
                    append(kind: .containers, url: child)
                } else if sensitivity == .deep,
                          let team = identity.teamID,
                          base.hasPrefix("\(team).") {
                    append(kind: .containers, url: child)
                }
            }
        }

        guard sensitivity == .deep else {
            return found.sorted { $0.byteCount > $1.byteCount }
        }

        // MARK: Deep — broader vendor prefix + Spotlight paths under ~/Library
        if let vendor, vendor.count >= 5 {
            for relative in ["Caches", "Application Support", "Logs", "HTTPStorages", "WebKit"] {
                let dir = library.appendingPathComponent(relative, isDirectory: true)
                guard let children = try? FileManager.default.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }
                for child in children where child.lastPathComponent.hasPrefix(vendor) {
                    let kind: LeftoverKind = relative == "Caches" ? .caches
                        : relative == "Logs" ? .logs
                        : .applicationSupport
                    append(kind: kind, url: child)
                }
            }
        }

        for url in spotlightLibraryHits(for: identity) {
            let kind = classifySpotlightPath(url, library: library)
            append(kind: kind, url: url)
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

                guard token.contains(".") else { continue }
                guard !isProtected(bundleID: token) else { continue }
                guard !installedBundleIDs.contains(token) else { continue }
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

    // MARK: - Matching helpers

    private static func normalizedNameTokens(_ name: String) -> [String] {
        let cleaned = name
            .replacingOccurrences(of: ".app", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 3 else { return [] }
        var tokens = [cleaned]
        let compact = cleaned.replacingOccurrences(of: " ", with: "")
        if compact != cleaned, compact.count >= 3 { tokens.append(compact) }
        return tokens
    }

    private static func matchesEnhanced(
        base: String,
        identity: AppIdentity,
        nameTokens: [String],
        vendor: String?
    ) -> Bool {
        if base.localizedCaseInsensitiveContains(identity.bundleID) { return true }
        if base.caseInsensitiveCompare(identity.bundleID) == .orderedSame { return true }
        for token in nameTokens {
            if base.caseInsensitiveCompare(token) == .orderedSame { return true }
        }
        if let vendor, base.hasPrefix(vendor) { return true }
        return false
    }

    private static func classifySpotlightPath(_ url: URL, library: URL) -> LeftoverKind {
        let path = url.path
        if path.contains("/Preferences/") { return .preferences }
        if path.contains("/Caches/") { return .caches }
        if path.contains("/Logs/") { return .logs }
        if path.contains("/Containers/") { return .containers }
        if path.contains("/Group Containers/") { return .groupContainers }
        if path.contains("/LaunchAgents/") { return .launchAgents }
        if path.contains("/Cookies/") { return .cookies }
        if path.contains("/Saved Application State/") { return .savedState }
        _ = library
        return .applicationSupport
    }

    /// Spotlight hits limited to ~/Library (Deep sensitivity only).
    private static func spotlightLibraryHits(for identity: AppIdentity) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let libraryPrefix = home + "/Library/"
        var queryParts = [
            "kMDItemFSName == '\(escapeSpotlight(identity.bundleID))*'cd",
            "kMDItemPath == '\(escapeSpotlight(libraryPrefix))*\(escapeSpotlight(identity.bundleID))*'c"
        ]
        if identity.appName.count >= 3 {
            queryParts.append(
                "kMDItemFSName == '\(escapeSpotlight(identity.appName))*'cd && kMDItemPath == '\(escapeSpotlight(libraryPrefix))*'c"
            )
        }
        let predicate = queryParts.joined(separator: " || ")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", home + "/Library", predicate]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return [] }
        return text
            .split(whereSeparator: \.isNewline)
            .prefix(80)
            .compactMap { line -> URL? in
                let path = String(line)
                guard path.hasPrefix(libraryPrefix) else { return nil }
                // Skip deep noise inside Containers data blobs except the container root-ish paths
                let url = URL(fileURLWithPath: path)
                // Prefer directory roots / plists — skip tiny nested files deep in trees
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
                if isDir.boolValue {
                    // Only keep shallow-ish leftovers (Library/<Area>/<name>)
                    let relative = path.dropFirst(libraryPrefix.count)
                    let depth = relative.split(separator: "/").count
                    guard depth <= 3 else { return nil }
                    return url
                }
                if url.pathExtension == "plist" || url.pathExtension == "binarycookies" {
                    return url
                }
                return nil
            }
    }

    private static func escapeSpotlight(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }
}
