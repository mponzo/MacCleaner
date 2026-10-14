import Foundation
import Observation

/// Paths (and prefixes) the user asked Smart Care to never select or remove.
@MainActor
@Observable
final class CleanupExclusions {
    static let shared = CleanupExclusions()

    private enum Keys {
        static let paths = "cleanup.exclusions.paths"
    }

    private(set) var paths: [String] = []

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: Keys.paths) ?? []
        paths = Self.normalized(stored).sorted()
    }

    var isEmpty: Bool { paths.isEmpty }

    func contains(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return paths.contains { excluded in
            path == excluded || path.hasPrefix(excluded.hasSuffix("/") ? excluded : excluded + "/")
        }
    }

    func add(_ url: URL) {
        let path = url.standardizedFileURL.path
        guard !path.isEmpty else { return }
        var next = Set(paths)
        next.insert(path)
        paths = Array(next).sorted()
        persist()
    }

    func remove(_ path: String) {
        paths.removeAll { $0 == path }
        persist()
    }

    func clear() {
        paths = []
        persist()
    }

    /// Drop excluded items; remaining keep their selection state.
    func filterItems(_ items: [ScanItem]) -> [ScanItem] {
        guard !paths.isEmpty else { return items }
        return items.filter { !contains($0.url) }
    }

    private func persist() {
        UserDefaults.standard.set(paths, forKey: Keys.paths)
    }

    private static func normalized(_ values: [String]) -> [String] {
        Array(Set(values.map { ($0 as NSString).standardizingPath }.filter { !$0.isEmpty }))
    }
}
