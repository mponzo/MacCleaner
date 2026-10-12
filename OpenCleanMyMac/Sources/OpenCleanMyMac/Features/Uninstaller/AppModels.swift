import AppKit
import Foundation

enum LeftoverKind: String, CaseIterable, Identifiable, Hashable, Sendable {
    case preferences
    case caches
    case applicationSupport
    case logs
    case savedState
    case cookies
    case containers
    case groupContainers
    case launchAgents
    case crashReporter

    var id: String { rawValue }

    var title: String {
        L10n.string(key: "leftover.\(rawValue)")
    }
}

struct AppLeftover: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: LeftoverKind
    let url: URL
    let byteCount: Int64
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        kind: LeftoverKind,
        url: URL,
        byteCount: Int64,
        isSelected: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.url = url
        self.byteCount = byteCount
        self.isSelected = isSelected
    }
}

struct InstalledApp: Identifiable, Hashable, Sendable {
    /// Stable across refreshes (bundle ID + path).
    var id: String { "\(bundleIdentifier)|\(bundleURL.path)" }
    let name: String
    let bundleIdentifier: String
    let version: String
    let bundleURL: URL
    let byteCount: Int64
    let isSystemApp: Bool
    let isProtected: Bool
    var leftovers: [AppLeftover]
    var includeAppBundle: Bool

    init(
        name: String,
        bundleIdentifier: String,
        version: String,
        bundleURL: URL,
        byteCount: Int64,
        isSystemApp: Bool,
        isProtected: Bool,
        leftovers: [AppLeftover] = [],
        includeAppBundle: Bool = true
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.bundleURL = bundleURL
        self.byteCount = byteCount
        self.isSystemApp = isSystemApp
        self.isProtected = isProtected
        self.leftovers = leftovers
        self.includeAppBundle = includeAppBundle && !isProtected && !isSystemApp
    }

    var leftoverBytes: Int64 { leftovers.reduce(0) { $0 + $1.byteCount } }
    var selectedLeftoverBytes: Int64 {
        leftovers.filter(\.isSelected).reduce(0) { $0 + $1.byteCount }
    }

    var uninstallBytes: Int64 {
        (includeAppBundle ? byteCount : 0) + selectedLeftoverBytes
    }
}

enum SidebarDestination: Hashable {
    case overview
    case applications
    case performance
    case privileged
    case spaceLens
    case updates
    case settings
    case category(ScanCategory)
}
