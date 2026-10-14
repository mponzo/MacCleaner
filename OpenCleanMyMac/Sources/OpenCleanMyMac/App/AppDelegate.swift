import AppKit

/// Keeps MacCleaner running in the menu bar after the main window is dismissed.
/// Full quit happens only via Settings → Esci (`NSApp.terminate`).
/// Also hosts the Finder Service “Uninstall with MacCleaner”.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didInstallCloseGuard = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPreferences.shared.finishLaunchSetup()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        installCloseGuardsIfNeeded()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .ocmmReopenMainWindow, object: nil)
        }
        return true
    }

    /// Finder Services entry — must match Info.plist `NSMessage` = `uninstallApp`.
    @objc func uninstallApp(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let urls = pboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty
        else {
            error.pointee = L10n.string("service.uninstall.no_app") as NSString
            return
        }

        let apps = urls.filter { $0.pathExtension.lowercased() == "app" }
        guard let first = apps.first ?? urls.first else {
            error.pointee = L10n.string("service.uninstall.no_app") as NSString
            return
        }

        let target = first.standardizedFileURL
        DispatchQueue.main.async {
            AppPreferences.shared.hideDockIcon = false
            AppPreferences.shared.applyActivationPolicy()
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .ocmmReopenMainWindow, object: nil)
            NotificationCenter.default.post(
                name: .ocmmUninstallAppFromService,
                object: nil,
                userInfo: ["url": target]
            )
        }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        installCloseGuardsIfNeeded()
    }

    private func installCloseGuardsIfNeeded() {
        for window in NSApp.windows where AppWindowActivator.isMainContentWindow(window) {
            MainWindowCloseGuard.install(on: window)
            didInstallCloseGuard = true
        }
    }
}

/// Redirects the red traffic-light close button to hide the window instead of destroying it.
final class MainWindowCloseGuard: NSObject {
    static let shared = MainWindowCloseGuard()

    static func install(on window: NSWindow) {
        guard let button = window.standardWindowButton(.closeButton) else { return }
        button.target = shared
        button.action = #selector(hideMainWindow(_:))
    }

    @objc private func hideMainWindow(_ sender: Any?) {
        let window: NSWindow? = {
            if let button = sender as? NSButton {
                return button.window
            }
            return NSApp.keyWindow
        }()
        guard let window, AppWindowActivator.isMainContentWindow(window) else {
            (sender as? NSButton)?.window?.performClose(nil)
            return
        }
        window.orderOut(nil)
        // Stay alive as a menu-bar app until Settings → Esci.
        NSApp.setActivationPolicy(.accessory)
    }
}

extension Notification.Name {
    static let ocmmReopenMainWindow = Notification.Name("ocmm.reopenMainWindow")
    static let ocmmUninstallAppFromService = Notification.Name("ocmm.uninstallAppFromService")
}
