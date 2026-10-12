import Foundation

enum DiskSizer {
    static func allocatedBytes(at url: URL) -> Int64 {
        let values: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey,
            .fileSizeKey
        ]

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }

        if !isDirectory.boolValue {
            return fileBytes(url, keys: values)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(values),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resource = try fileURL.resourceValues(forKeys: values)
                if resource.isSymbolicLink == true { continue }
                if resource.isDirectory == true { continue }
                total += allocated(from: resource)
            } catch {
                continue
            }
        }
        return total
    }

    private static func fileBytes(_ url: URL, keys: Set<URLResourceKey>) -> Int64 {
        (try? url.resourceValues(forKeys: keys)).map(allocated(from:)) ?? 0
    }

    private static func allocated(from values: URLResourceValues) -> Int64 {
        if let total = values.totalFileAllocatedSize { return Int64(total) }
        if let allocated = values.fileAllocatedSize { return Int64(allocated) }
        if let size = values.fileSize { return Int64(size) }
        return 0
    }
}
