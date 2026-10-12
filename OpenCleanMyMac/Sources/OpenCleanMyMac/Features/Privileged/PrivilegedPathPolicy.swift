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

    static func isRemovable(_ url: URL) -> Bool {
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
