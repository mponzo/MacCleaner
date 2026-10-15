import ArgumentParser
import Foundation

struct MacCleanerCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maccleaner",
        abstract: "MacCleaner command-line interface — local scan and cleanup (same engines as the app).",
        discussion: """
        Run with no subcommand for the interactive workspace (TTY).
        Destructive actions use an interactive review, or --dry-run / --confirm for scripts.
        System-privileged paths are skipped by clean unless --include-privileged is set \
        (still uses the app allowlist / admin bridge — not raw sudo).
        """,
        version: "\(CLISupport.appVersion) (\(CLISupport.appBuild))",
        subcommands: [
            ScanCommand.self,
            CleanCommand.self,
            AppsCommand.self,
            OrphansCommand.self,
            DoctorCommand.self
        ]
    )

    @Flag(name: .long, help: "Use numbered text prompts instead of the full-screen TUI.")
    var plain = false

    func run() throws {
        CLISupport.installSignalHandler()
        try CLIWorkspace.run(plain: plain)
    }
}

// MARK: - scan

struct ScanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan reclaimable categories and print a summary (read-only)."
    )

    @Option(name: .customLong("category"), parsing: .singleValue, help: "Limit to category rawValue (repeatable).")
    var categories: [String] = []

    @Flag(name: .long, help: "Emit JSON instead of text.")
    var json = false

    func run() throws {
        CLISupport.installSignalHandler()
        let filter = try CLISupport.resolveCategories(categories)
        let json = self.json
        try CLISupport.runAsync {
            let results: [CategoryResult]
            if json {
                // Keep stdout clean for machines — progress would break JSON.
                results = await CLIScan.collect(categories: filter)
            } else {
                results = await CLIScan.collectWithProgress(categories: filter, title: "Scanning")
            }
            let total = results.reduce(Int64(0)) { $0 + $1.totalBytes }

            if json {
                try Self.printScanJSON(results: results, total: total)
                return
            }

            print("MacCleaner scan — \(CLISupport.appVersion)")
            for result in results where result.totalBytes > 0 || !result.items.isEmpty {
                let selected = result.items.filter(\.isSelected).count
                print(
                    "\(result.category.rawValue)\t\(result.items.count) items\t\(ByteFormat.string(result.totalBytes))\tselected=\(selected)"
                )
            }
            print("TOTAL\t\(ByteFormat.string(total))")
            if CLISupport.cancelled {
                CLISupport.printErr("Scan stopped early.")
                throw ExitCode(130)
            }
        }
    }

    private static func printScanJSON(results: [CategoryResult], total: Int64) throws {
        let payload: [String: Any] = [
            "version": CLISupport.appVersion,
            "totalBytes": total,
            "categories": results.map { result -> [String: Any] in
                [
                    "id": result.category.rawValue,
                    "title": result.category.title,
                    "itemCount": result.items.count,
                    "bytes": result.totalBytes,
                    "selectedBytes": result.selectedBytes,
                    "cleanable": result.category.isCleanable,
                    "requiresPrivilege": result.category.requiresPrivilege
                ]
            }
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}

// MARK: - clean

struct CleanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Interactive review, dry-run, or move selected Smart Care items to Trash."
    )

    @Flag(name: .customLong("dry-run"), help: "List what would be trashed; do not delete.")
    var dryRun = false

    @Flag(name: .long, help: "Actually move selected items to Trash (non-interactive default selection).")
    var confirm = false

    @Flag(name: .long, help: "Numbered text selection instead of the full-screen TUI.")
    var plain = false

    @Option(name: .customLong("category"), parsing: .singleValue, help: "Limit to category rawValue (repeatable).")
    var categories: [String] = []

    @Flag(name: .customLong("include-privileged"), help: "Include system allowlisted categories (may prompt for admin).")
    var includePrivileged = false

    func validate() throws {
        if dryRun && confirm {
            throw ValidationError("Use either --dry-run or --confirm, not both.")
        }
    }

    func run() throws {
        CLISupport.installSignalHandler()
        let filter = try CLISupport.resolveCategories(categories)
        let dryRun = self.dryRun
        let confirm = self.confirm
        let plain = self.plain
        let includePrivileged = self.includePrivileged

        // No script flags → interactive (or plain) selection workspace flow.
        if !dryRun && !confirm {
            try CLISupport.runAsync {
                try await CLIWorkspace.runCleanFlow(
                    plain: plain,
                    includePrivileged: includePrivileged,
                    categories: filter
                )
            }
            return
        }

        try CLISupport.runAsync {
            let results = await CLIScan.collectWithProgress(categories: filter, title: "Scanning")
            let items = CLIScan.selectableItems(from: results, includePrivileged: includePrivileged)
            guard !items.isEmpty else { throw CLIError.nothingToClean }

            let bytes = items.reduce(Int64(0)) { $0 + $1.byteCount }
            print("\(items.count) items · \(ByteFormat.string(bytes))")

            if dryRun {
                for item in items.prefix(200) {
                    print("DRY-RUN\t\(ByteFormat.string(item.byteCount))\t\(item.url.path)")
                }
                if items.count > 200 {
                    print("… \(items.count - 200) more")
                }
                print("Dry-run complete — nothing was moved.")
                return
            }

            let trashProgress = CLIProgress(title: "Trashing", total: max(1, items.count))
            trashProgress.start(detail: "\(items.count) items")
            let result = await Cleaner.moveToTrash(items) { CLISupport.cancelled }
            trashProgress.finish("Moved \(result.movedCount) · freed \(ByteFormat.string(result.freedBytes))")
            if !result.failed.isEmpty {
                CLISupport.printErr("Failed: \(result.failed.count)")
                for (url, message) in result.failed.prefix(20) {
                    CLISupport.printErr(" - \(url.path): \(message)")
                }
                throw ExitCode(1)
            }
            if CLISupport.cancelled {
                throw ExitCode(130)
            }
        }
    }
}

// MARK: - apps

struct AppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List user apps and leftover sizes (sample)."
    )

    @Flag(name: .long, help: "Also list orphan leftovers summary.")
    var leftovers = false

    @Option(name: .long, help: "How many apps to enrich with leftovers (default 12).")
    var limit: Int = 12

    func run() throws {
        let leftovers = self.leftovers
        let limit = self.limit
        try CLISupport.runAsync {
            print("MacCleaner apps")
            let apps = await ApplicationsCatalog.listInstalledApps()
            let userApps = apps.filter { !$0.isSystemApp && !$0.isProtected }
            print("Installed user apps: \(userApps.count)")

            let sample = Array(userApps.prefix(max(limit, 0)))
            let enriched = await ApplicationsCatalog.enrichWithLeftovers(sample)
            for app in enriched.sorted(by: { $0.leftoverBytes > $1.leftoverBytes }) {
                print(
                    "\(app.name)\tapp \(ByteFormat.string(app.byteCount))\tleftovers \(app.leftovers.count) / \(ByteFormat.string(app.leftoverBytes))"
                )
            }

            if leftovers {
                let ids = Set(apps.map(\.bundleIdentifier))
                let orphans = await LeftoverDiscovery.orphanLeftovers(installedBundleIDs: ids)
                let orphanBytes = orphans.reduce(Int64(0)) { $0 + $1.byteCount }
                print("Orphan leftovers: \(orphans.count) · \(ByteFormat.string(orphanBytes))")
            }
        }
    }
}

// MARK: - orphans

struct OrphansCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "orphans",
        abstract: "List or interactively trash leftovers with no matching installed app."
    )

    @Flag(name: .customLong("dry-run"), help: "Preview trash of all listed orphans.")
    var dryRun = false

    @Flag(name: .long, help: "Move listed orphans to Trash (all of them, non-interactive).")
    var confirm = false

    @Flag(name: .long, help: "Open interactive selection (default on a TTY when no other flags).")
    var interactive = false

    @Flag(name: .long, help: "Numbered text selection instead of the full-screen TUI.")
    var plain = false

    func validate() throws {
        if dryRun && confirm {
            throw ValidationError("Use either --dry-run or --confirm, not both.")
        }
    }

    func run() throws {
        CLISupport.installSignalHandler()
        let dryRun = self.dryRun
        let confirm = self.confirm
        let plain = self.plain
        let wantInteractive = interactive || (!dryRun && !confirm && CLITerminalSession.isSupported)

        if wantInteractive && !dryRun && !confirm {
            try CLISupport.runAsync {
                try await CLIWorkspace.runOrphansFlow(plain: plain)
            }
            return
        }

        try CLISupport.runAsync {
            let apps = await ApplicationsCatalog.listInstalledApps()
            let ids = Set(apps.map(\.bundleIdentifier))
            let orphans = await LeftoverDiscovery.orphanLeftovers(installedBundleIDs: ids)
            let bytes = orphans.reduce(Int64(0)) { $0 + $1.byteCount }
            print("Orphans: \(orphans.count) · \(ByteFormat.string(bytes))")

            for orphan in orphans {
                print("\(orphan.kind.title)\t\(ByteFormat.string(orphan.byteCount))\t\(orphan.url.path)")
            }

            guard dryRun || confirm else { return }
            var selected = orphans.map {
                ScanItem(
                    category: .appLeftovers,
                    url: $0.url,
                    byteCount: $0.byteCount,
                    displayName: $0.url.lastPathComponent,
                    isSelected: true
                )
            }
            for i in selected.indices { selected[i].isSelected = true }

            if dryRun {
                print("Dry-run — \(selected.count) orphans would move to Trash.")
                return
            }

            let result = await Cleaner.moveToTrash(selected) { CLISupport.cancelled }
            print("Moved \(result.movedCount) · freed \(ByteFormat.string(result.freedBytes))")
            if !result.failed.isEmpty {
                throw ExitCode(1)
            }
        }
    }
}

// MARK: - doctor

struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Environment checks: version, FDA, Homebrew, privileged bridge."
    )

    @Flag(name: .long, help: "Include a short performance sample (legacy --perf-once).")
    var perf = false

    @Flag(name: .long, help: "Include privileged path inventory (legacy --priv-once).")
    var priv = false

    func run() throws {
        let perf = self.perf
        let priv = self.priv
        try CLISupport.runAsync {
            print("MacCleaner \(CLISupport.appVersion) (build \(CLISupport.appBuild))")
            print("Binary: \(CommandLine.arguments.first ?? "?")")

            // Static probe — avoids MainActor deadlock while CLI blocks the main thread.
            print("Full Disk Access: \(FullDiskAccessManager.probe() ? "yes" : "no")")

            if let brew = Self.resolveBrewPath() {
                print("Homebrew: \(brew)")
            } else {
                print("Homebrew: not found")
            }

            print(PrivilegedBridge.statusSummary())
            print("Allowlist roots:")
            for root in PrivilegedPathPolicy.allowedRoots {
                print(" - \(root)")
            }

            if perf {
                _ = MetricsCollector.shared.snapshot(limit: 8)
                try await Task.sleep(nanoseconds: 350_000_000)
                let (metrics, top) = MetricsCollector.shared.snapshot(limit: 8)
                print(String(format: "CPU busy %.0f%%", metrics.cpuLoadPercent))
                print(String(format: "Memory used %.0f%%", metrics.memoryUsedPercent))
                print("Disk free \(ByteFormat.string(metrics.diskFreeBytes))")
                print("Top memory:")
                for p in top.prefix(5) {
                    print(String(format: " - %@  %@", p.name, ByteFormat.string(Int64(p.memoryBytes))))
                }
                let agents = LaunchAgentScanner.scan()
                let broken = agents.filter(\.isBroken)
                print("Launch agents: \(agents.count) (\(broken.count) broken)")
            }

            if priv {
                let caches = await SystemCachesScanner().scan()
                let logs = await SystemLogsScanner().scan()
                let agents = await SystemLaunchAgentsScanner().scan()
                print("System caches: \(caches.count) · \(ByteFormat.string(caches.reduce(0) { $0 + $1.byteCount }))")
                print("System logs: \(logs.count) · \(ByteFormat.string(logs.reduce(0) { $0 + $1.byteCount }))")
                print("Broken system agents: \(agents.count)")
            }
        }
    }

    private static func resolveBrewPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "\(NSHomeDirectory())/homebrew/bin/brew"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
