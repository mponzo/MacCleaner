import AppKit
import Foundation
import Observation

struct SpaceNode: Identifiable, Hashable, Sendable {
    var id: String { url.path }
    let url: URL
    let name: String
    let isDirectory: Bool
    let byteCount: Int64
}

@MainActor
@Observable
final class SpaceExplorerEngine {
    var rootURL: URL?
    var children: [SpaceNode] = []
    var isScanning = false
    var progressLabel = L10n.string("space.explorer.idle")
    var errorMessage: String?
    var breadcrumb: [URL] = []

    private var workTask: Task<Void, Never>?

    var totalBytes: Int64 {
        children.reduce(0) { $0 + $1.byteCount }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = L10n.string("space.explorer.choose")
        panel.message = L10n.string("space.explorer.choose_message")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    func openHome() {
        open(URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
    }

    func openApplications() {
        open(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }

    func open(_ url: URL) {
        let standardized = url.standardizedFileURL
        rootURL = standardized
        breadcrumb = Self.breadcrumb(for: standardized)
        refresh()
    }

    func openParent() {
        guard let rootURL else { return }
        let parent = rootURL.deletingLastPathComponent()
        guard parent.path != rootURL.path, parent.path.hasPrefix("/") else { return }
        open(parent)
    }

    func drill(into node: SpaceNode) {
        guard node.isDirectory else {
            NSWorkspace.shared.activateFileViewerSelecting([node.url])
            return
        }
        open(node.url)
    }

    func revealCurrent() {
        guard let rootURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([rootURL])
    }

    func stop() {
        workTask?.cancel()
        workTask = nil
        isScanning = false
        progressLabel = L10n.string("space.explorer.stopped")
    }

    func refresh() {
        guard let rootURL else { return }
        workTask?.cancel()
        workTask = Task { await measure(root: rootURL) }
    }

    private func measure(root: URL) async {
        isScanning = true
        errorMessage = nil
        children = []
        progressLabel = L10n.string("space.explorer.measuring")

        let nodes: [SpaceNode]
        do {
            nodes = try await Task.detached(priority: .userInitiated) {
                try SpaceExplorerListing.listChildren(of: root) {
                    Task.isCancelled
                }
            }.value
        } catch is CancellationError {
            progressLabel = L10n.string("space.explorer.stopped")
            isScanning = false
            return
        } catch {
            errorMessage = error.localizedDescription
            progressLabel = L10n.string("space.explorer.failed")
            isScanning = false
            return
        }

        if Task.isCancelled {
            progressLabel = L10n.string("space.explorer.stopped")
            isScanning = false
            return
        }

        children = nodes
        progressLabel = L10n.format(
            "space.explorer.summary",
            Int64(nodes.count),
            ByteFormat.string(nodes.reduce(0) { $0 + $1.byteCount })
        )
        isScanning = false
    }

    private static func breadcrumb(for url: URL) -> [URL] {
        var parts: [URL] = []
        var current = url.standardizedFileURL
        while current.path != "/" {
            parts.append(current)
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { break }
            current = parent
        }
        parts.append(URL(fileURLWithPath: "/", isDirectory: true))
        return parts.reversed()
    }
}

enum SpaceExplorerListing {
    static func listChildren(
        of root: URL,
        isCancelled: () -> Bool
    ) throws -> [SpaceNode] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .isPackageKey,
            .nameKey
        ]
        let contents = try fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )

        var nodes: [SpaceNode] = []
        nodes.reserveCapacity(contents.count)

        for child in contents {
            if isCancelled() { throw CancellationError() }
            let values = try? child.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true { continue }

            let isPackage = values?.isPackage == true
            let isDirectory = (values?.isDirectory == true) && !isPackage
            let bytes = DiskSizer.allocatedBytes(at: child)
            if bytes <= 0 && !isDirectory { continue }

            nodes.append(
                SpaceNode(
                    url: child,
                    name: values?.name ?? child.lastPathComponent,
                    isDirectory: isDirectory,
                    byteCount: bytes
                )
            )
        }

        return nodes.sorted { lhs, rhs in
            if lhs.byteCount != rhs.byteCount { return lhs.byteCount > rhs.byteCount }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
