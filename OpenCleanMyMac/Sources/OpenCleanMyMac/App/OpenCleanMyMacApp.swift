import AppKit
import SwiftUI

@main
struct OpenCleanMyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var engine = ScanEngine()
    @State private var uninstaller = UninstallerEngine()
    @State private var performance = PerformanceEngine()
    @State private var privileged = PrivilegedHelperEngine()
    @State private var updater = AppUpdateEngine()
    @State private var preferences = AppPreferences.shared

    init() {
        let headless = CommandLine.arguments.contains(where: {
            $0 == "--scan-once" || $0 == "--apps-once" || $0 == "--perf-once" || $0 == "--priv-once"
        })
        if !headless {
            SingleInstanceGuard.enforceOrExit()
        }

        if CommandLine.arguments.contains("--scan-once") {
            HeadlessScan.runAndExit()
        }
        if CommandLine.arguments.contains("--apps-once") {
            HeadlessApps.runAndExit()
        }
        if CommandLine.arguments.contains("--perf-once") {
            HeadlessPerf.runAndExit()
        }
        if CommandLine.arguments.contains("--priv-once") {
            HeadlessPriv.runAndExit()
        }
    }

    var body: some Scene {
        // Single unique window — avoids a new WindowGroup instance on every openWindow().
        Window("MacCleaner", id: "main") {
            RootView(
                engine: engine,
                uninstaller: uninstaller,
                performance: performance,
                privileged: privileged,
                updater: updater,
                preferences: preferences
            )
            .preferredColorScheme(.dark)
            .background(OCTheme.canvas)
            .id(preferences.languageRevision)
            .onAppear {
                AppWindowActivator.collapseDuplicates()
            }
        }
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            // No menu Quit / Cmd+Q — full exit only from Settings (or menu bar Esci).
            CommandGroup(replacing: .appTermination) {}
            CommandMenu(L10n.string("menu.clean")) {
                Button(L10n.string("menu.run_smart_care")) {
                    engine.runSmartCare()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button(L10n.string("menu.clean_selected")) {
                    engine.cleanSelected()
                }
                .keyboardShortcut("k", modifiers: [.command])
                .disabled(engine.reclaimableBytes == 0)

                Divider()

                Button(L10n.string("menu.refresh_apps")) {
                    Task { await uninstaller.refresh() }
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Button(L10n.string("menu.refresh_perf")) {
                    Task { await performance.refreshAll() }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra(isInserted: $preferences.showMenuBarIcon) {
            MenuBarView(
                preferences: preferences,
                engine: engine,
                performance: performance
            )
        } label: {
            Label(l10n: "app.name", systemImage: "internaldrive.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

enum HeadlessScan {
    static func runAndExit() {
        let sema = DispatchSemaphore(value: 0)
        Task {
            print("MacCleaner — headless Smart Care")
            var total: Int64 = 0
            for scanner in ScannerRegistry.all {
                let items = await scanner.scan()
                let bytes = items.reduce(Int64(0)) { $0 + $1.byteCount }
                total += bytes
                print("\(scanner.category.title): \(items.count) items, \(ByteFormat.string(bytes))")
            }
            print("TOTAL: \(ByteFormat.string(total))")
            sema.signal()
        }
        sema.wait()
        Foundation.exit(0)
    }
}

enum HeadlessApps {
    static func runAndExit() {
        let sema = DispatchSemaphore(value: 0)
        Task {
            print("MacCleaner — headless Applications / leftovers")
            let apps = await ApplicationsCatalog.listInstalledApps()
            let userApps = apps.filter { !$0.isSystemApp && !$0.isProtected }
            print("Installed user apps: \(userApps.count)")

            let sample = Array(userApps.prefix(12))
            let enriched = await ApplicationsCatalog.enrichWithLeftovers(sample)
            for app in enriched.sorted(by: { $0.leftoverBytes > $1.leftoverBytes }) {
                print("\(app.name): app \(ByteFormat.string(app.byteCount)), leftovers \(app.leftovers.count) / \(ByteFormat.string(app.leftoverBytes))")
            }

            let ids = Set(apps.map(\.bundleIdentifier))
            let orphans = await LeftoverDiscovery.orphanLeftovers(installedBundleIDs: ids)
            let orphanBytes = orphans.reduce(Int64(0)) { $0 + $1.byteCount }
            print("Orphan leftovers: \(orphans.count) items, \(ByteFormat.string(orphanBytes))")
            for orphan in orphans.prefix(15) {
                print(" - [\(orphan.kind.title)] \(orphan.url.lastPathComponent) \(ByteFormat.string(orphan.byteCount))")
            }
            sema.signal()
        }
        sema.wait()
        Foundation.exit(0)
    }
}

enum HeadlessPerf {
    static func runAndExit() {
        // Keep fully synchronous: blocking main in App.init + awaiting Task can deadlock.
        print("MacCleaner — headless Performance")

        let metrics = MetricsCollector.snapshot()
        var metricsWithCount = metrics
        let top = MetricsCollector.topProcesses(limit: 8)
        metricsWithCount.processCount = top.count
        print(String(
            format: "Memory used %.0f%% (%@ / %@)",
            metricsWithCount.memoryUsedPercent,
            ByteFormat.string(Int64(metricsWithCount.usedMemoryBytes)),
            ByteFormat.string(Int64(metricsWithCount.physicalMemoryBytes))
        ))
        print(String(format: "CPU ticks busy %.0f%%", metricsWithCount.cpuLoadPercent))
        print("Disk free \(ByteFormat.string(metricsWithCount.diskFreeBytes)) / \(ByteFormat.string(metricsWithCount.diskTotalBytes))")
        print("Sampled processes: \(top.count)")
        print("Top memory:")
        for p in top {
            print(String(format: " - %@  %@  %.1f%% CPU", p.name, ByteFormat.string(Int64(p.memoryBytes)), p.cpuPercent))
        }

        let agents = LaunchAgentScanner.scan()
        let broken = agents.filter(\.isBroken)
        print("Launch agents: \(agents.count) (\(broken.count) broken)")
        for agent in broken.prefix(10) {
            print(" - BROKEN \(agent.label) → \(agent.executablePath ?? "?")")
        }
        Foundation.exit(0)
    }
}

enum HeadlessPriv {
    static func runAndExit() {
        print("MacCleaner — privileged bridge status")
        print(PrivilegedBridge.statusSummary())
        print("Allowlist roots:")
        for root in PrivilegedPathPolicy.allowedRoots {
            print(" - \(root)")
        }

        let sema = DispatchSemaphore(value: 0)
        Task.detached {
            let caches = await SystemCachesScanner().scan()
            let logs = await SystemLogsScanner().scan()
            let agents = await SystemLaunchAgentsScanner().scan()
            let cacheBytes = caches.reduce(Int64(0)) { $0 + $1.byteCount }
            let logBytes = logs.reduce(Int64(0)) { $0 + $1.byteCount }
            print("System caches: \(caches.count) items, \(ByteFormat.string(cacheBytes))")
            for item in caches.prefix(8) {
                print(" - \(item.displayName) \(ByteFormat.string(item.byteCount))")
            }
            print("System logs: \(logs.count) items, \(ByteFormat.string(logBytes))")
            print("Broken system agents: \(agents.count)")
            for item in agents.prefix(8) {
                print(" - \(item.displayName)")
            }
            sema.signal()
        }
        sema.wait()
        Foundation.exit(0)
    }
}
