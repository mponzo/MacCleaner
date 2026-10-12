import Foundation

enum LaunchAgentScanner {
    static func scan() -> [LaunchAgentItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots: [(URL, Bool)] = [
            (home.appendingPathComponent("Library/LaunchAgents", isDirectory: true), true),
            (URL(fileURLWithPath: "/Library/LaunchAgents", isDirectory: true), false)
        ]

        var items: [LaunchAgentItem] = []
        for (root, isUser) in roots {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension == "plist" {
                let plist = readPlist(file)
                let label = (plist["Label"] as? String) ?? file.deletingPathExtension().lastPathComponent
                let executable = resolveExecutable(from: plist)
                let broken = isBroken(executablePath: executable)
                let bytes = DiskSizer.allocatedBytes(at: file)
                items.append(
                    LaunchAgentItem(
                        label: label,
                        url: file,
                        executablePath: executable,
                        isBroken: broken,
                        isUserDomain: isUser,
                        byteCount: max(bytes, 1),
                        isSelected: broken && isUser
                    )
                )
            }
        }

        return items.sorted {
            if $0.isBroken != $1.isBroken { return $0.isBroken && !$1.isBroken }
            return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    private static func readPlist(_ url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = obj as? [String: Any]
        else { return [:] }
        return dict
    }

    private static func resolveExecutable(from plist: [String: Any]) -> String? {
        if let program = plist["Program"] as? String {
            return program
        }
        if let args = plist["ProgramArguments"] as? [String], let first = args.first {
            return first
        }
        return nil
    }

    private static func isBroken(executablePath: String?) -> Bool {
        guard let executablePath, !executablePath.isEmpty else { return true }
        let expanded = (executablePath as NSString).expandingTildeInPath
        // Relative commands like `sh` live on PATH — treat as OK.
        if !expanded.contains("/") {
            return false
        }
        return !FileManager.default.fileExists(atPath: expanded)
    }
}
