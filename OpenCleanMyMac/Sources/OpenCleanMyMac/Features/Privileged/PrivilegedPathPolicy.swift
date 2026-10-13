import Foundation

/// Allowlist for privileged remove/cache/log paths.
/// Only paths under these roots may be mutated with administrator privileges.
enum PrivilegedPathPolicy {
    static let allowedRoots: [String] = [
        "/Library/Caches",
        "/Library/Logs",
        "/Library/LaunchAgents",
        "/private/var/log"
    ]

    static let blockedNameMarkers: [String] = [
        "..",
        "/System/",
        "/usr/",
        "/bin/",
        "/sbin/",
        "/etc/",
        "/dev/",
        "/Applications/",
        "/Library/Apple/",
        "/Library/Frameworks/",
        "/Library/PrivilegedHelperTools/"
    ]

    static func needsPrivilege(for url: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return false }
        return true
    }

    /// User-installed `.app` under `/Applications` or `~/Applications` (never `/System`).
    /// These are blocked from the cache/log allowlist but must still be uninstallable.
    static func isUserApplicationBundle(_ url: URL) -> Bool {
        var path = url.resolvingSymlinksInPath().standardizedFileURL.path
        while path.hasSuffix("/") { path.removeLast() }
        guard path.hasSuffix(".app") else { return false }
        if path.hasPrefix("/System/") { return false }

        let homeApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .path
        let roots = ["/Applications/", homeApps.hasSuffix("/") ? homeApps : homeApps + "/"]
        guard let root = roots.first(where: { path.hasPrefix($0) }) else { return false }

        for marker in blockedNameMarkers where marker != "/Applications/" {
            if path.contains(marker) { return false }
        }
        let rest = String(path.dropFirst(root.count))
        return !rest.isEmpty && !rest.contains("..")
    }

    static func isRemovable(_ url: URL) -> Bool {
        if isUserApplicationBundle(url) { return true }
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard path.hasPrefix("/") else { return false }
        for marker in blockedNameMarkers where path.contains(marker) {
            return false
        }
        // Must be strictly inside an allowed root (not the root itself for Caches/Logs).
        for root in allowedRoots {
            if path == root { return false }
            if path.hasPrefix(root + "/") { return true }
        }
        return false
    }

    static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
