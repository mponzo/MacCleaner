import AppKit

/// Keeps MacCleaner running in the menu bar after the main window is dismissed.
/// Full quit happens only via Settings → Esci (`NSApp.terminate`).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didInstallCloseGuard = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPreferences.shared.finishLaunchSetup()
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
}
