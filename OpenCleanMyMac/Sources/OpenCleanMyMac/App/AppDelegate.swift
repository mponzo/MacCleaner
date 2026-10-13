import AppKit

/// Keeps MacCleaner running in the menu bar after the main window is closed.
/// Full quit happens only via Settings → Esci.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppPreferences.shared.finishLaunchSetup()
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
}

extension Notification.Name {
    static let ocmmReopenMainWindow = Notification.Name("ocmm.reopenMainWindow")
}
