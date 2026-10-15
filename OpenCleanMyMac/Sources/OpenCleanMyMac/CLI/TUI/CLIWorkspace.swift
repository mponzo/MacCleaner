import ArgumentParser
import Foundation

/// Interactive workspace opened by bare `maccleaner` (TTY).
enum CLIWorkspace {
    static func run(plain: Bool = false) throws {
        if plain || !CLITerminalSession.isSupported {
            try runPlainMenu()
            return
        }
        try runInteractiveMenu()
    }

    // MARK: - Interactive menu

    private static func runInteractiveMenu() throws {
        let options: [(title: String, detail: String)] = [
            ("Smart Care clean", "Scan reclaimable categories, select, move to Trash"),
            ("Orphan leftovers", "Find leftovers with no matching installed app"),
            ("Installed apps", "List user apps and leftover sizes (sample)"),
            ("Doctor", "FDA, Homebrew, privileged bridge status"),
            ("Quit", "Leave the workspace")
        ]

        while true {
            guard let choice = try choose(
                title: "MacCleaner workspace",
                subtitle: "Same engines as the app · cleanup goes to Trash",
                options: options
            ) else {
                return
            }

            switch choice {
            case 0:
                try CLISupport.runAsync { try await runCleanFlow(plain: false, includePrivileged: false) }
            case 1:
                try CLISupport.runAsync { try await runOrphansFlow(plain: false) }
            case 2:
                try CLISupport.runAsync { await runAppsFlow() }
                pauseReturn()
            case 3:
                try CLISupport.runAsync { await runDoctorFlow() }
                pauseReturn()
            default:
                return
            }
        }
    }

    private static func choose(
        title: String,
        subtitle: String,
        options: [(title: String, detail: String)]
    ) throws -> Int? {
        let session = try CLITerminalSession()
        defer { session.close() }

        var selection = 0
        while true {
            session.draw(lines: renderMenu(
                title: title,
                subtitle: subtitle,
                options: options,
                selection: selection,
                width: session.width,
                height: session.height
            ))

            switch session.readKey() {
            case .up:
                selection = max(0, selection - 1)
            case .down:
                selection = min(options.count - 1, selection + 1)
            case .home:
                selection = 0
            case .end:
                selection = options.count - 1
            case .enter:
                return selection
            case .escape:
                return nil
            case .character(let ch):
                let s = String(ch).lowercased()
                if s == "q" { return nil }
                if let n = ch.wholeNumberValue, (1...options.count).contains(n) {
                    return n - 1
                }
            default:
                break
            }
        }
    }

    private static func renderMenu(
        title: String,
        subtitle: String,
        options: [(title: String, detail: String)],
        selection: Int,
        width: Int,
        height: Int
    ) -> [String] {
        let w = max(1, width)
        let h = max(1, height)
        var lines = [
            CLITerm.dim("MACCLEANER / WORKSPACE"),
            CLITerm.bold(CLITerm.cyan(CLITerm.truncate(title, to: w))),
            CLITerm.dim(CLITerm.truncate(subtitle, to: w)),
            ""
        ]
        let footer = 3
        let visible = max(1, (h - lines.count - footer) / 2)
        let start = max(0, min(max(0, options.count - visible), selection - visible / 2))

        for (index, option) in options.enumerated().dropFirst(start).prefix(visible) {
            let focused = index == selection
            let number = CLITerm.pad("\(index + 1).", to: 4)
            let titleLine = "\(focused ? "›" : " ") \(number)\(CLITerm.truncate(option.title, to: max(1, w - 6)))"
            let detailLine = "      " + CLITerm.truncate(option.detail, to: max(1, w - 6))
            lines.append(focused ? CLITerm.inverse(titleLine) : titleLine)
            lines.append(focused ? CLITerm.bold(detailLine) : CLITerm.dim(detailLine))
        }

        while lines.count < h - footer { lines.append("") }
        lines.append(CLITerm.dim(String(repeating: "─", count: w)))
        lines.append(CLITerm.dim("↑↓ move  1–9 open  Enter open  Esc/q quit"))
        return Array(lines.prefix(h))
    }

    // MARK: - Plain menu

    private static func runPlainMenu() throws {
        while true {
            print("")
            print(CLITerm.bold("MacCleaner workspace"))
            print("  1  Smart Care clean")
            print("  2  Orphan leftovers")
            print("  3  Installed apps")
            print("  4  Doctor")
            print("  q  Quit")
            print("> ", terminator: "")
            fflush(stdout)
            guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                return
            }
            switch line {
            case "1":
                try CLISupport.runAsync { try await runCleanFlow(plain: true, includePrivileged: false) }
            case "2":
                try CLISupport.runAsync { try await runOrphansFlow(plain: true) }
            case "3":
                try CLISupport.runAsync { await runAppsFlow() }
            case "4":
                try CLISupport.runAsync { await runDoctorFlow() }
            case "q", "quit", "":
                return
            default:
                print("Unknown option.")
            }
        }
    }

    // MARK: - Flows

    static func runCleanFlow(plain: Bool, includePrivileged: Bool, categories: Set<ScanCategory>? = nil) async throws {
        let results = await CLIScan.collectWithProgress(categories: categories, title: "Scanning")

        var items = results
            .flatMap(\.items)
            .filter { $0.category.isCleanable }
        if !includePrivileged {
            items = items.filter { !$0.category.requiresPrivilege }
        }
        items.sort { $0.byteCount > $1.byteCount }

        guard !items.isEmpty else {
            print("Nothing reclaimable found.")
            return
        }

        guard let selected = try CLIReview.select(
            items: items,
            title: "Smart Care — select what to trash",
            plain: plain
        ) else {
            print("Cancelled.")
            return
        }

        // Final confirm outside alt-screen
        print("")
        print(CLITerm.bold("Move \(selected.count) items (\(ByteFormat.string(selected.reduce(0) { $0 + $1.byteCount }))) to Trash?"))
        print("Type yes to continue: ", terminator: "")
        fflush(stdout)
        let answer = (readLine() ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        guard answer == "yes" else {
            print("Aborted.")
            return
        }

        var toTrash = selected
        for i in toTrash.indices { toTrash[i].isSelected = true }

        let trashProgress = CLIProgress(title: "Trashing", total: max(1, toTrash.count))
        trashProgress.start(detail: "\(toTrash.count) items")
        let result = await Cleaner.moveToTrash(toTrash) { CLISupport.cancelled }
        trashProgress.finish(
            CLITerm.green("Moved \(result.movedCount) · freed \(ByteFormat.string(result.freedBytes))")
        )
        if !result.failed.isEmpty {
            CLISupport.printErr("Failed: \(result.failed.count)")
            for (url, message) in result.failed.prefix(20) {
                CLISupport.printErr(" - \(url.path): \(message)")
            }
            throw ExitCode(1)
        }
    }

    static func runOrphansFlow(plain: Bool) async throws {
        let progress = CLIProgress(title: "Scanning orphans", total: 2)
        progress.start(detail: "apps")
        let apps = await ApplicationsCatalog.listInstalledApps()
        progress.update(step: 1, detail: "leftovers")
        let ids = Set(apps.map(\.bundleIdentifier))
        let orphans = await LeftoverDiscovery.orphanLeftovers(installedBundleIDs: ids)
        progress.finish()

        guard !orphans.isEmpty else {
            print("No orphan leftovers found.")
            return
        }

        let items = orphans.map {
            ScanItem(
                category: .appLeftovers,
                url: $0.url,
                byteCount: $0.byteCount,
                displayName: $0.url.lastPathComponent,
                isSelected: true
            )
        }

        guard let selected = try CLIReview.select(
            items: items,
            title: "Orphans — select leftovers to trash",
            plain: plain
        ) else {
            print("Cancelled.")
            return
        }

        print("")
        print(CLITerm.bold("Move \(selected.count) orphans to Trash?"))
        print("Type yes to continue: ", terminator: "")
        fflush(stdout)
        let answer = (readLine() ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        guard answer == "yes" else {
            print("Aborted.")
            return
        }

        var toTrash = selected
        for i in toTrash.indices { toTrash[i].isSelected = true }
        let trashProgress = CLIProgress(title: "Trashing", total: max(1, toTrash.count))
        trashProgress.start(detail: "orphans")
        let result = await Cleaner.moveToTrash(toTrash) { CLISupport.cancelled }
        trashProgress.finish(
            CLITerm.green("Moved \(result.movedCount) · freed \(ByteFormat.string(result.freedBytes))")
        )
        if !result.failed.isEmpty { throw ExitCode(1) }
    }

    static func runAppsFlow() async {
        let progress = CLIProgress(title: "Listing apps", total: 2)
        progress.start(detail: "catalog")
        let apps = await ApplicationsCatalog.listInstalledApps()
        let userApps = apps.filter { !$0.isSystemApp && !$0.isProtected }
        progress.update(step: 1, detail: "leftovers")
        let sample = Array(userApps.prefix(12))
        let enriched = await ApplicationsCatalog.enrichWithLeftovers(sample)
        progress.finish("MacCleaner apps — \(userApps.count) user apps")
        for app in enriched.sorted(by: { $0.leftoverBytes > $1.leftoverBytes }) {
            print(
                "\(app.name)\tapp \(ByteFormat.string(app.byteCount))\tleftovers \(app.leftovers.count) / \(ByteFormat.string(app.leftoverBytes))"
            )
        }
    }

    static func runDoctorFlow() async {
        print("MacCleaner \(CLISupport.appVersion) (build \(CLISupport.appBuild))")
        print("Full Disk Access: \(FullDiskAccessManager.probe() ? "yes" : "no")")
        let brewCandidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "\(NSHomeDirectory())/homebrew/bin/brew"
        ]
        if let brew = brewCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            print("Homebrew: \(brew)")
        } else {
            print("Homebrew: not found")
        }
        print(PrivilegedBridge.statusSummary())
    }

    private static func pauseReturn() {
        print("")
        print(CLITerm.dim("Press Enter to return…"), terminator: "")
        fflush(stdout)
        _ = readLine()
    }
}
