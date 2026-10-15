import Foundation

enum CLISupport {
    nonisolated(unsafe) static var cancelled = false

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "dev"
    }

    static var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0"
    }

    static func installSignalHandler() {
        signal(SIGINT) { _ in
            CLISupport.cancelled = true
            fputs("\nInterrupted — stopping after the current item.\n", stderr)
        }
    }

    static func resolveCategories(_ raw: [String]) throws -> Set<ScanCategory>? {
        guard !raw.isEmpty else { return nil }
        var set = Set<ScanCategory>()
        for token in raw {
            guard let cat = ScanCategory(rawValue: token) else {
                let known = ScanCategory.allCases.map(\.rawValue).joined(separator: ", ")
                throw CLIError.invalidCategory(token, known)
            }
            set.insert(cat)
        }
        return set
    }

    /// Runs async work off the main thread. Avoid `MainActor.run` inside `work`
    /// while this waits — that deadlocks the CLI bootstrap on the main thread.
    static func runAsync(_ work: @escaping @Sendable () async throws -> Void) throws {
        let sema = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var captured: Error?
        Task.detached(priority: .userInitiated) {
            do {
                try await work()
            } catch {
                captured = error
            }
            sema.signal()
        }
        sema.wait()
        if let captured { throw captured }
    }

    /// Read exclusion paths without hopping to the main actor (CLI-safe).
    static func exclusionPaths() -> [String] {
        let stored = UserDefaults.standard.stringArray(forKey: "cleanup.exclusions.paths") ?? []
        return Array(Set(stored.map { ($0 as NSString).standardizingPath }.filter { !$0.isEmpty })).sorted()
    }

    static func isExcluded(_ url: URL, paths: [String]) -> Bool {
        let path = url.standardizedFileURL.path
        return paths.contains { excluded in
            path == excluded || path.hasPrefix(excluded.hasSuffix("/") ? excluded : excluded + "/")
        }
    }

    static func printErr(_ message: String) {
        fputs(message + "\n", stderr)
    }
}

enum CLIError: Error, CustomStringConvertible {
    case invalidCategory(String, String)
    case cleanModeRequired
    case nothingToClean

    var description: String {
        switch self {
        case .invalidCategory(let token, let known):
            return "Unknown category '\(token)'. Known: \(known)"
        case .cleanModeRequired:
            return "Use interactive `maccleaner clean`, or pass --dry-run / --confirm."
        case .nothingToClean:
            return "No selected cleanable items matched."
        }
    }
}

enum CLIScan {
    static func collect(categories: Set<ScanCategory>?) async -> [CategoryResult] {
        let scanners = ScannerRegistry.all.filter { scanner in
            guard let categories else { return true }
            return categories.contains(scanner.category)
        }
        var results: [CategoryResult] = []
        for scanner in scanners {
            if CLISupport.cancelled { break }
            let items = await scanner.scan()
            let exclusions = CLISupport.exclusionPaths()
            let filtered = items.filter { !CLISupport.isExcluded($0.url, paths: exclusions) }
            results.append(CategoryResult(category: scanner.category, items: filtered))
        }
        results.sort { $0.totalBytes > $1.totalBytes }
        return results
    }

    static func selectableItems(
        from results: [CategoryResult],
        includePrivileged: Bool
    ) -> [ScanItem] {
        let exclusions = CLISupport.exclusionPaths()
        return results
            .flatMap(\.items)
            .filter { item in
                guard item.isSelected, item.category.isCleanable else { return false }
                if item.category.requiresPrivilege, !includePrivileged { return false }
                return !CLISupport.isExcluded(item.url, paths: exclusions)
            }
    }
}
