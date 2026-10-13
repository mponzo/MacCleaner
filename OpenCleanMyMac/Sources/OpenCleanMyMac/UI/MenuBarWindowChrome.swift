import AppKit
import SwiftUI

/// Makes the MenuBarExtra panel transparent so glass materials show through.
struct MenuBarWindowChrome: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            Self.apply(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            Self.apply(to: nsView.window)
        }
    }

    private static func apply(to window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        // Tall enough for the one-click panel without an inner scroll view.
        let preferred = NSSize(width: 380, height: 760)
        if window.contentMinSize.height < preferred.height {
            window.contentMinSize = preferred
        }
        if window.frame.height < preferred.height {
            window.setContentSize(preferred)
        }
        if #available(macOS 14.0, *) {
            window.collectionBehavior.insert(.fullScreenAuxiliary)
        }
    }
}
