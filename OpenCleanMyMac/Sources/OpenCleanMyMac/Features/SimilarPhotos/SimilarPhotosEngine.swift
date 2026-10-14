import AppKit
import Foundation
import Observation

struct SimilarPhotoItem: Identifiable, Hashable, Sendable {
    let id: URL
    let url: URL
    let byteCount: Int64
    /// Compact fingerprint: average RGB + 8x8 luminance bits.
    let fingerprint: PhotoFingerprint
}

struct PhotoFingerprint: Hashable, Sendable {
    let avgR: UInt8
    let avgG: UInt8
    let avgB: UInt8
    let aspectBucket: UInt8
    let bits: UInt64

    func distance(to other: PhotoFingerprint) -> Int {
        let color = abs(Int(avgR) - Int(other.avgR))
            + abs(Int(avgG) - Int(other.avgG))
            + abs(Int(avgB) - Int(other.avgB))
        let aspect = avgR == other.avgR && aspectBucket != other.aspectBucket ? 8 : abs(Int(aspectBucket) - Int(other.aspectBucket)) * 2
        let hamming = (bits ^ other.bits).nonzeroBitCount
        return color / 12 + aspect + hamming
    }
}

struct SimilarPhotoGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    var photos: [SimilarPhotoItem]
}

private enum SimilarPhotosLimits {
    static let maxPhotos = 500
    static let maxDirectoryEntries = 10_000
    /// Lower = more similar. Tuned for coarse thumbnail fingerprints.
    static let similarityThreshold = 10
}

@MainActor
@Observable
final class SimilarPhotosEngine {
    static var maxPhotos: Int { SimilarPhotosLimits.maxPhotos }
    static var maxDirectoryEntries: Int { SimilarPhotosLimits.maxDirectoryEntries }
    static var similarityThreshold: Int { SimilarPhotosLimits.similarityThreshold }

    var isScanning = false
    var progressLabel = L10n.string("photos.idle")
    var rootURL: URL?
    var groups: [SimilarPhotoGroup] = []
    var scannedCount = 0
    var hitLimit = false
    var errorMessage: String?

    private var workTask: Task<Void, Never>?

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.string("photos.choose")
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
        isScanning = false
        progressLabel = L10n.string("photos.stopped")
    }

    private func scan(root: URL) async {
        isScanning = true
        errorMessage = nil
        groups = []
        scannedCount = 0
        hitLimit = false
        progressLabel = L10n.string("photos.scanning")
        rootURL = root

        let outcome = await Task.detached(priority: .userInitiated) {
            Self.scanFolder(root: root)
        }.value

        if Task.isCancelled {
            progressLabel = L10n.string("photos.stopped")
            isScanning = false
            return
        }

        groups = outcome.groups
        scannedCount = outcome.scanned
        hitLimit = outcome.hitLimit
        if groups.isEmpty {
            progressLabel = L10n.string("photos.empty")
        } else {
            progressLabel = L10n.format("photos.summary", Int64(groups.count), Int64(scannedCount))
        }
        isScanning = false
    }

    private struct ScanOutcome: Sendable {
        var groups: [SimilarPhotoGroup]
        var scanned: Int
        var hitLimit: Bool
    }

    nonisolated private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "webp", "bmp"
    ]

    nonisolated private static func scanFolder(root: URL) -> ScanOutcome {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey, .ubiquitousItemDownloadingStatusKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ScanOutcome(groups: [], scanned: 0, hitLimit: false)
        }

        var items: [SimilarPhotoItem] = []
        var entries = 0
        var hitLimit = false

        while let node = enumerator.nextObject() {
            guard let url = node as? URL else { continue }
            if Task.isCancelled { break }
            entries += 1
            if entries > SimilarPhotosLimits.maxDirectoryEntries {
                hitLimit = true
                break
            }

            let ext = url.pathExtension.lowercased()
            if ["app", "photoslibrary", "framework", "bundle"].contains(ext) {
                enumerator.skipDescendants()
                continue
            }
            guard imageExtensions.contains(ext) else { continue }
            guard let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
            ]) else { continue }
            if values.isSymbolicLink == true { continue }
            guard values.isRegularFile == true else { continue }

            // Skip iCloud placeholders when possible.
            if let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus,
               status == .notDownloaded {
                continue
            }

            guard let fingerprint = fingerprint(for: url) else { continue }
            let bytes = Int64(values.fileSize ?? 0)
            items.append(SimilarPhotoItem(id: url, url: url, byteCount: bytes, fingerprint: fingerprint))

            if items.count >= SimilarPhotosLimits.maxPhotos {
                hitLimit = true
                break
            }
        }

        let groups = cluster(items)
        return ScanOutcome(groups: groups, scanned: items.count, hitLimit: hitLimit)
    }

    nonisolated private static func fingerprint(for url: URL) -> PhotoFingerprint? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        let target = NSSize(width: 32, height: 32)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width),
            pixelsHigh: Int(target.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        guard let rep else { return nil }
        NSGraphicsContext.saveGraphicsState()
        if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = ctx
            image.draw(
                in: NSRect(origin: .zero, size: target),
                from: .zero,
                operation: .copy,
                fraction: 1.0
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        var sumR = 0, sumG = 0, sumB = 0
        var luma: [Double] = []
        luma.reserveCapacity(64)
        let stepX = 4
        let stepY = 4
        for y in stride(from: 0, to: 32, by: stepY) {
            for x in stride(from: 0, to: 32, by: stepX) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let r = Int((color.redComponent * 255).rounded())
                let g = Int((color.greenComponent * 255).rounded())
                let b = Int((color.blueComponent * 255).rounded())
                sumR += r; sumG += g; sumB += b
                luma.append(0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b))
            }
        }
        guard luma.count == 64 else { return nil }
        let avgLuma = luma.reduce(0, +) / Double(luma.count)
        var bits: UInt64 = 0
        for (i, value) in luma.enumerated() where value >= avgLuma {
            bits |= (1 << UInt64(i))
        }
        let aspect: UInt8
        if image.size.width <= 0 || image.size.height <= 0 {
            aspect = 1
        } else {
            let ratio = image.size.width / image.size.height
            aspect = UInt8(min(20, max(1, Int((ratio * 10).rounded()))))
        }
        return PhotoFingerprint(
            avgR: UInt8(sumR / 64),
            avgG: UInt8(sumG / 64),
            avgB: UInt8(sumB / 64),
            aspectBucket: aspect,
            bits: bits
        )
    }

    nonisolated private static func cluster(_ items: [SimilarPhotoItem]) -> [SimilarPhotoGroup] {
        var unused = items
        var groups: [SimilarPhotoGroup] = []
        while let seed = unused.first {
            unused.removeFirst()
            var cluster = [seed]
            var i = 0
            while i < unused.count {
                let candidate = unused[i]
                let close = cluster.contains {
                    $0.fingerprint.distance(to: candidate.fingerprint) <= SimilarPhotosLimits.similarityThreshold
                }
                if close {
                    cluster.append(candidate)
                    unused.remove(at: i)
                } else {
                    i += 1
                }
            }
            if cluster.count >= 2 {
                groups.append(SimilarPhotoGroup(id: UUID(), photos: cluster))
            }
        }
        groups.sort { $0.photos.count > $1.photos.count }
        return groups
    }
}
