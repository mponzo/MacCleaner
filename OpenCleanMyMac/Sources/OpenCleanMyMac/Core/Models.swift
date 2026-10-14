import Foundation

enum ScanCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case userCaches
    case userLogs
    case trash
    case xcodeDerivedData
    case xcodeArchives
    case developerCaches
    case aiAppCaches
    case downloadsClutter
    case unusedDiskImages
    case browserCaches
    case mailDownloads
    case mailData
    case largeOldFiles
    case largeHomeFolders
    case appLeftovers
    case brokenLaunchAgents
    case systemCaches
    case systemLogs
    case systemLaunchAgents

    var id: String { rawValue }

    var title: String {
        L10n.string(key: "category.\(rawValue).title")
    }

    var detail: String {
        L10n.string(key: "category.\(rawValue).detail")
    }

    var isCleanable: Bool {
        switch self {
        case .largeHomeFolders:
            return false
        default:
            return true
        }
    }

    /// Prefer off-by-default for personal mail indexes, large/old review files, and AI models.
    var defaultSelected: Bool {
        switch self {
        case .mailData, .largeOldFiles, .aiAppCaches:
            return false
        default:
            return isCleanable
        }
    }

    /// Categories whose selected items usually need the privileged bridge.
    var requiresPrivilege: Bool {
        switch self {
        case .systemCaches, .systemLogs, .systemLaunchAgents:
            return true
        default:
            return false
        }
    }

    var systemImage: String {
        switch self {
        case .userCaches: return "internaldrive"
        case .userLogs: return "doc.text"
        case .trash: return "trash"
        case .xcodeDerivedData: return "hammer"
        case .xcodeArchives: return "shippingbox"
        case .developerCaches: return "chevron.left.forwardslash.chevron.right"
        case .aiAppCaches: return "brain.head.profile"
        case .downloadsClutter: return "arrow.down.circle"
        case .unusedDiskImages: return "opticaldisc"
        case .browserCaches: return "globe"
        case .mailDownloads: return "envelope.badge"
        case .mailData: return "envelope"
        case .largeOldFiles: return "doc.badge.clock"
        case .largeHomeFolders: return "chart.bar"
        case .appLeftovers: return "app.badge.checkmark"
        case .brokenLaunchAgents: return "exclamationmark.triangle"
        case .systemCaches: return "externaldrive.fill.badge.checkmark"
        case .systemLogs: return "doc.text.below.ecg"
        case .systemLaunchAgents: return "gearshape.2"
        }
    }
}

struct ScanItem: Identifiable, Hashable {
    let id: UUID
    let category: ScanCategory
    let url: URL
    let byteCount: Int64
    let displayName: String
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        category: ScanCategory,
        url: URL,
        byteCount: Int64,
        displayName: String? = nil,
        isSelected: Bool = true
    ) {
        self.id = id
        self.category = category
        self.url = url
        self.byteCount = byteCount
        self.displayName = displayName ?? url.lastPathComponent
        // Cleanable + caller wants selection + category default-on (mail data stays off).
        self.isSelected = category.isCleanable && isSelected && category.defaultSelected
    }
}

struct CategoryResult: Identifiable, Hashable {
    var id: ScanCategory { category }
    let category: ScanCategory
    var items: [ScanItem]

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.byteCount } }
    var selectedBytes: Int64 { items.filter(\.isSelected).reduce(0) { $0 + $1.byteCount } }
}

struct CleanResult: Sendable {
    let freedBytes: Int64
    let movedCount: Int
    let failed: [(URL, String)]
}

enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
