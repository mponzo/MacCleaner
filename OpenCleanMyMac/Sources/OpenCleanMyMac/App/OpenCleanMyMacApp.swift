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
    @State private var brewUpdates = HomebrewCaskEngine()
    @State private var duplicates = DuplicateFinderEngine()
    @State private var similarPhotos = SimilarPhotosEngine()
    @State private var scheduler = CleanupScheduler()
    @State private var spaceExplorer = SpaceExplorerEngine()
    @State private var orphanFinder = OrphanFinderEngine()
    @State private var startup = StartupEngine()
    @State private var developer = DeveloperCleanupEngine()
    @State private var privacy = PrivacyHubEngine()
    @State private var preferences = AppPreferences.shared

    init() {
        if CLIBootstrap.isCLIInvocation {
            CLIBootstrap.runAndExit()
        }

        OCTheme.registerFonts()
        SingleInstanceGuard.enforceOrExit()
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
                brewUpdates: brewUpdates,
                preferences: preferences,
                duplicates: duplicates,
                similarPhotos: similarPhotos,
                scheduler: scheduler,
                spaceExplorer: spaceExplorer,
                orphanFinder: orphanFinder,
                startup: startup,
                developer: developer,
                privacy: privacy
            )
            .preferredColorScheme(.dark)
            .background(OCTheme.canvas)
            .id(preferences.languageRevision)
            .onAppear {
                AppWindowActivator.collapseDuplicates()
                scheduler.attach(engine: engine)
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
                    uninstaller.refresh()
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
            Label(l10n: "app.name", systemImage: "broom.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
