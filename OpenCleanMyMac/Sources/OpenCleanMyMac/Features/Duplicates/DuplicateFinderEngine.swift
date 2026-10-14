import AppKit
import CryptoKit
import Foundation
import Observation

struct DuplicateFileItem: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let byteCount: Int64
    let inode: UInt64
    var isProtected: Bool
    var isSelected: Bool
}

struct DuplicateGroup: Identifiable, Hashable, Sendable {
    let id: String
    let sha256: String
    var files: [DuplicateFileItem]

    var totalBytes: Int64 { files.reduce(0) { $0 + $1.byteCount } }
    var reclaimableBytes: Int64 {
        files.filter { !$0.isProtected && $0.isSelected }.reduce(0) { $0 + $1.byteCount }
    }
}

@MainActor
@Observable
final class DuplicateFinderEngine {
    var isScanning = false
    var isCleaning = false
    var progressLabel = L10n.string("dup.idle")
    var rootURL: URL?
    var groups: [DuplicateGroup] = []
    var skippedCount = 0
    var errorMessage: String?
    var lastResult: CleanResult?
    var operationProgress: Double?
    var operationDetail: String?

    private var workTask: Task<Void, Never>?

    var isBusy: Bool { isScanning || isCleaning }

    var reclaimableBytes: Int64 {
        groups.reduce(0) { $0 + $1.reclaimableBytes }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.string("dup.choose")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        rootURL = url
        startScan(at: url)
    }

    func startScan(at url: URL? = nil) {
        let root = url ?? rootURL
        guard let root, !isScanning else { return }
        workTask?.cancel()
        workTask = Task { await self.scan(root: root) }
    }

    func stop() {
        workTask?.cancel()
        workTask = nil
        if isScanning || isCleaning {
            progressLabel = L10n.string("dup.stopped")
        }
        isScanning = false
        isCleaning = false
        operationProgress = nil
        operationDetail = nil
    }

    func toggle(groupID: String, fileID: URL) {
        guard let gIdx = groups.firstIndex(where: { $0.id == groupID }),
              let fIdx = groups[gIdx].files.firstIndex(where: { $0.id == fileID })
        else { return }
        guard !groups[gIdx].files[fIdx].isProtected else { return }
        groups[gIdx].files[fIdx].isSelected.toggle()
    }

    func cleanSelected() {
        guard !isScanning, !isCleaning else { return }
        workTask?.cancel()
        workTask = Task { await self.performClean() }
    }

    private func scan(root: URL) async {
        isScanning = true
        operationProgress = -1
        operationDetail = nil
        errorMessage = nil
        lastResult = nil
        groups = []
        skippedCount = 0
        progressLabel = L10n.string("dup.scanning")
        rootURL = root

        let outcome = await Task.detached(priority: .userInitiated) {
            Self.scanFolder(root: root)
        }.value

        if Task.isCancelled {
            progressLabel = L10n.string("dup.stopped")
            isScanning = false
            operationProgress = nil
            operationDetail = nil
            return
        }

        groups = outcome.groups
        skippedCount = outcome.skipped
        progressLabel = groups.isEmpty
            ? L10n.string("dup.empty")
            : L10n.format("dup.summary", Int64(groups.count), ByteFormat.string(reclaimableBytes))
        isScanning = false
        operationProgress = nil
        operationDetail = nil
    }

    private func performClean() async {
        isCleaning = true
        progressLabel = L10n.string("dup.trashing")
        let urls = groups.flatMap(\.files).filter { !$0.isProtected && $0.isSelected }.map(\.url)
        let items = urls.map {
            ScanItem(category: .downloadsClutter, url: $0, byteCount: DiskSizer.allocatedBytes(at: $0), isSelected: true)
        }
        let total = max(items.count, 1)
        var completed = 0
        var freed: Int64 = 0
        var moved = 0
        var failed: [(URL, String)] = []
        operationProgress = 0
        operationDetail = L10n.format("operation.step", Int64(0), Int64(total))

        for item in items {
            if Task.isCancelled { break }
            progressLabel = L10n.format("dev.cleaning_item", item.displayName)
            let result = await Cleaner.moveToTrash([item], isCancelled: { Task.isCancelled })
            freed += result.freedBytes
            moved += result.movedCount
            failed.append(contentsOf: result.failed)
            completed += 1
            operationProgress = Double(completed) / Double(total)
            operationDetail = L10n.format("operation.step", Int64(completed), Int64(total))
        }

        let result = CleanResult(freedBytes: freed, movedCount: moved, failed: failed)
        let wasCancelled = Task.isCancelled
        isCleaning = false
        operationProgress = nil
        operationDetail = nil

        if moved > 0 || freed > 0 {
            lastResult = result
            CleanupHistoryStore.shared.record(
                result: result,
                source: .duplicates,
                detail: rootURL?.lastPathComponent
            )
        }
        if wasCancelled {
            progressLabel = L10n.string("dup.stopped")
            return
        }
        if !result.failed.isEmpty {
            errorMessage = L10n.format("dup.failed", Int64(result.failed.count))
        }
        progressLabel = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
        if let rootURL {
            await scan(root: rootURL)
        }
    }

    private struct ScanOutcome: Sendable {
        var groups: [DuplicateGroup]
        var skipped: Int
    }

    nonisolated private static func scanFolder(root: URL) -> ScanOutcome {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            return ScanOutcome(groups: [], skipped: 0)
        }

        var bySize: [Int64: [URL]] = [:]
        var skipped = 0

        while let node = enumerator.nextObject() {
            guard let url = node as? URL else { continue }
            if Task.isCancelled { break }

            let ext = url.pathExtension.lowercased()
            if ["app", "photoslibrary", "framework", "bundle"].contains(ext) {
                enumerator.skipDescendants()
                skipped += 1
                continue
            }

            guard let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey
            ]) else {
                skipped += 1
                continue
            }
            if values.isSymbolicLink == true {
                skipped += 1
                continue
            }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else {
                skipped += 1
                continue
            }
            let size = Int64(values.fileSize ?? 0)
            guard size > 0 else { continue }
            bySize[size, default: []].append(url)
        }

        var groups: [DuplicateGroup] = []

        for (size, urls) in bySize where urls.count > 1 {
            if Task.isCancelled { break }
            var byHash: [String: [(URL, UInt64)]] = [:]
            for url in urls {
                if Task.isCancelled { break }
                guard let inode = inode(of: url), let digest = sha256(of: url) else {
                    skipped += 1
                    continue
                }
                byHash[digest, default: []].append((url, inode))
            }

            for (digest, entries) in byHash {
                var uniqueByInode: [UInt64: URL] = [:]
                for (url, inode) in entries {
                    if uniqueByInode[inode] == nil {
                        uniqueByInode[inode] = url
                    }
                }
                guard uniqueByInode.count > 1 else { continue }

                var files: [DuplicateFileItem] = uniqueByInode.map { inode, url in
                    DuplicateFileItem(
                        id: url,
                        url: url,
                        byteCount: size,
                        inode: inode,
                        isProtected: false,
                        isSelected: true
                    )
                }
                .sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }

                files[0].isProtected = true
                files[0].isSelected = false

                groups.append(DuplicateGroup(id: digest, sha256: digest, files: files))
            }
        }

        groups.sort { $0.totalBytes > $1.totalBytes }
        return ScanOutcome(groups: groups, skipped: skipped)
    }

    nonisolated private static func inode(of url: URL) -> UInt64? {
        var statInfo = stat()
        guard stat(url.path, &statInfo) == 0 else { return nil }
        return UInt64(statInfo.st_ino)
    }

    nonisolated private static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while true {
                let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
                if chunk.isEmpty { break }
                hasher.update(data: chunk)
            }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
}
