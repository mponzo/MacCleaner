import AppKit
import SwiftUI

enum AppWindowActivator {
    /// Brings the single main window forward; opens it only if none exists.
    static func bringMainToFront(openWindow: OpenWindowAction) {
        if let window = mainWindow() {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        openWindow(id: "main")
        DispatchQueue.main.async {
            mainWindow()?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Close duplicate main windows left over from earlier builds.
    static func collapseDuplicates() {
        let windows = mainWindows()
        guard windows.count > 1 else { return }
        for window in windows.dropFirst() {
            window.close()
        }
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private static func mainWindow() -> NSWindow? {
        mainWindows().first
    }

    private static func mainWindows() -> [NSWindow] {
        NSApp.windows.filter { isMainContentWindow($0) }
    }

    private static func isMainContentWindow(_ window: NSWindow) -> Bool {
        // Exclude MenuBarExtra / status item panels and utility chrome.
        guard window.level == .normal else { return false }
        let className = String(describing: type(of: window))
        if className.localizedCaseInsensitiveContains("StatusItem")
            || className.localizedCaseInsensitiveContains("MenuBar")
            || className.localizedCaseInsensitiveContains("NSStatus")
        {
            return false
        }
        // Main UI is a sizable document-like window.
        return window.frame.width >= 600 && window.frame.height >= 400
    }
}
