import Foundation

/// Keyboard-driven item selection (Space toggle, Enter review, Esc cancel).
enum CLIReview {
    struct Row {
        var item: ScanItem
        var selected: Bool
    }

    /// Returns selected items, or `nil` if the user cancelled.
    static func select(
        items: [ScanItem],
        title: String,
        plain: Bool
    ) throws -> [ScanItem]? {
        var rows = items.map { Row(item: $0, selected: false) }
        if plain || !CLITerminalSession.isSupported {
            return try plainSelect(&rows, title: title)
        }
        return try interactiveSelect(&rows, title: title)
    }

    // MARK: - Interactive

    private static func interactiveSelect(_ rows: inout [Row], title: String) throws -> [ScanItem]? {
        let session = try CLITerminalSession()
        defer { session.close() }

        var focus = 0
        var query = ""
        var searching = false
        var reviewing = false
        var status = ""
        var pathOffset = 0

        func matchingIndices() -> [Int] {
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return rows.indices.filter { i in
                guard needle.isEmpty else {
                    let hay = "\(rows[i].item.category.rawValue) \(rows[i].item.url.path)".lowercased()
                    return hay.contains(needle)
                }
                return true
            }
        }

        func selectedIndices() -> [Int] {
            rows.indices.filter { rows[$0].selected }
        }

        func activeIndices() -> [Int] {
            reviewing ? selectedIndices() : matchingIndices()
        }

        while true {
            let indices = activeIndices()
            if !indices.isEmpty {
                focus = min(focus, indices.count - 1)
            } else {
                focus = 0
            }

            session.draw(
                lines: render(
                    rows: rows,
                    indices: indices,
                    focus: focus,
                    title: title,
                    query: query,
                    searching: searching,
                    reviewing: reviewing,
                    status: status,
                    pathOffset: pathOffset,
                    width: session.width,
                    height: session.height
                )
            )

            let key = session.readKey()

            if searching {
                switch key {
                case .enter:
                    searching = false
                case .escape:
                    searching = false
                    query = ""
                    focus = 0
                case .backspace, .delete:
                    if !query.isEmpty { query.removeLast() }
                    focus = 0
                case .space:
                    query.append(" ")
                    focus = 0
                case .character(let ch) where !ch.isASCIIControl:
                    query.append(ch)
                    focus = 0
                default:
                    break
                }
                continue
            }

            switch key {
            case .up:
                focus = max(0, focus - 1)
                pathOffset = 0
            case .down:
                focus = min(max(0, indices.count - 1), focus + 1)
                pathOffset = 0
            case .pageUp:
                focus = max(0, focus - max(1, session.height / 2))
                pathOffset = 0
            case .pageDown:
                focus = min(max(0, indices.count - 1), focus + max(1, session.height / 2))
                pathOffset = 0
            case .home:
                focus = 0
                pathOffset = 0
            case .end:
                focus = max(0, indices.count - 1)
                pathOffset = 0
            case .left:
                pathOffset = max(0, pathOffset - max(8, session.width / 3))
            case .right:
                pathOffset += max(8, session.width / 3)
            case .space:
                guard !reviewing, indices.indices.contains(focus) else { break }
                let i = indices[focus]
                rows[i].selected.toggle()
            case .enter:
                if reviewing {
                    return rows.filter(\.selected).map(\.item)
                }
                if selectedIndices().isEmpty {
                    status = "Select at least one item"
                } else {
                    reviewing = true
                    focus = 0
                    pathOffset = 0
                    status = ""
                }
            case .escape:
                if reviewing {
                    reviewing = false
                    status = ""
                } else {
                    return nil
                }
            case .character(let ch):
                switch String(ch).lowercased() {
                case "a" where !reviewing:
                    for i in matchingIndices() { rows[i].selected = true }
                    status = "Selected matching items"
                case "n" where !reviewing:
                    for i in rows.indices { rows[i].selected = false }
                    status = "Selection cleared"
                case "/" where !reviewing:
                    searching = true
                    status = ""
                case "q":
                    return nil
                default:
                    break
                }
            default:
                break
            }
        }
    }

    private static func render(
        rows: [Row],
        indices: [Int],
        focus: Int,
        title: String,
        query: String,
        searching: Bool,
        reviewing: Bool,
        status: String,
        pathOffset: Int,
        width: Int,
        height: Int
    ) -> [String] {
        let w = max(1, width)
        let h = max(1, height)
        if w < 40 || h < 12 {
            return [
                CLITerm.bold(CLITerm.cyan(CLITerm.truncate("MacCleaner", to: w))),
                CLITerm.truncate("Terminal too small (need 40×12)", to: w),
                CLITerm.dim(CLITerm.truncate("Esc/q cancel", to: w))
            ]
        }

        let selectedCount = rows.filter(\.selected).count
        let selectedBytes = rows.filter(\.selected).reduce(Int64(0)) { $0 + $1.item.byteCount }
        let totalBytes = rows.reduce(Int64(0)) { $0 + $1.item.byteCount }

        var lines: [String] = [
            CLITerm.dim("MACCLEANER / \(reviewing ? "FINAL REVIEW" : "SELECT ITEMS")"),
            CLITerm.bold(CLITerm.cyan(CLITerm.truncate(title, to: w))),
            statusLine(
                left: "\(indices.count) shown · \(ByteFormat.string(totalBytes))",
                right: "\(selectedCount) selected · \(ByteFormat.string(selectedBytes))",
                width: w
            )
        ]

        if searching {
            lines.append(CLITerm.cyan("Search ") + CLITerm.truncate(query, to: max(1, w - 10)) + CLITerm.inverse(" "))
        } else if !status.isEmpty {
            lines.append(CLITerm.yellow(CLITerm.truncate(status, to: w)))
        } else if !query.isEmpty {
            lines.append(CLITerm.dim("Filter ") + CLITerm.truncate(query, to: max(1, w - 9)))
        } else {
            lines.append("")
        }

        let footer = 5
        let body = max(3, h - lines.count - footer)
        let start = max(0, min(max(0, indices.count - body), focus - body / 2))
        let slice = indices.dropFirst(start).prefix(body)

        var lastCategory: ScanCategory?
        for (offset, rowIndex) in slice.enumerated() {
            let row = rows[rowIndex]
            let focused = (start + offset) == focus
            if lastCategory != row.item.category {
                lastCategory = row.item.category
                lines.append(" " + CLITerm.bold(CLITerm.cyan(CLITerm.truncate(row.item.category.title.uppercased(), to: w - 2))))
            }
            let mark = row.selected ? CLITerm.cyan("●") : CLITerm.dim("○")
            let pointer = focused ? CLITerm.cyan("›") : " "
            let size = CLITerm.pad(ByteFormat.string(row.item.byteCount), to: 10)
            let pathW = max(6, w - 17)
            let path = CLITerm.truncate(CLITerm.shortenPath(row.item.url.path), to: pathW, middle: true)
            let content = "\(pointer) \(mark) \(size) \(path)"
            lines.append(focused ? CLITerm.inverse(content) : content)
        }

        while lines.count < h - footer { lines.append("") }

        lines.append(CLITerm.dim(String(repeating: "─", count: w)))
        if indices.indices.contains(focus) {
            let path = CLITerm.shortenPath(rows[indices[focus]].item.url.path)
            lines.append(CLITerm.dim("Path ") + horizontalWindow(path, offset: pathOffset, width: max(1, w - 6)))
        } else {
            lines.append(CLITerm.dim("Path —"))
        }
        if reviewing {
            lines.append(CLITerm.dim("↑↓ scroll  ←→ path"))
            lines.append(CLITerm.dim("Enter confirm  Esc edit  q cancel"))
            lines.append(CLITerm.yellow("Next: confirm move to Trash"))
        } else {
            lines.append(CLITerm.dim("↑↓ move  ←→ path  Space toggle"))
            lines.append(CLITerm.dim("A all  N none  / search"))
            lines.append(CLITerm.dim("Enter review  Esc/q cancel"))
        }
        return Array(lines.prefix(h))
    }

    private static func statusLine(left: String, right: String, width: Int) -> String {
        let avail = max(1, width - 2)
        if CLITerm.displayWidth(left) + CLITerm.displayWidth(right) <= avail {
            return CLITerm.pad(left, to: avail - CLITerm.displayWidth(right)) + " " + CLITerm.bold(right)
        }
        let rightBudget = min(CLITerm.displayWidth(right), max(1, avail / 2))
        let leftBudget = max(1, avail - rightBudget)
        return CLITerm.pad(CLITerm.truncate(left, to: leftBudget), to: leftBudget)
            + " " + CLITerm.bold(CLITerm.truncate(right, to: rightBudget))
    }

    private static func horizontalWindow(_ value: String, offset: Int, width: Int) -> String {
        let chars = Array(CLITerm.sanitize(value))
        let start = min(max(0, offset), chars.count)
        let prefix = start > 0 ? "‹" : ""
        var out = ""
        var used = CLITerm.displayWidth(prefix)
        var i = start
        while i < chars.count {
            let piece = String(chars[i])
            let cw = CLITerm.displayWidth(piece)
            let more = i + 1 < chars.count ? 1 : 0
            guard used + cw + more <= width else { break }
            out.append(chars[i])
            used += cw
            i += 1
        }
        let suffix = i < chars.count ? "›" : ""
        return prefix + out + suffix
    }

    // MARK: - Plain

    private static func plainSelect(_ rows: inout [Row], title: String) throws -> [ScanItem]? {
        print(CLITerm.bold("MacCleaner — \(title)"))
        print(CLITerm.dim("Enter numbers to toggle (e.g. 1 3 5), a=all, n=none, Enter=review, q=quit"))
        print("")

        while true {
            for (i, row) in rows.enumerated() {
                let mark = row.selected ? "[x]" : "[ ]"
                print("\(String(format: "%3d", i + 1)) \(mark) \(CLITerm.pad(ByteFormat.string(row.item.byteCount), to: 10)) \(CLITerm.shortenPath(row.item.url.path))")
            }
            let sel = rows.filter(\.selected)
            print("")
            print("\(sel.count) selected · \(ByteFormat.string(sel.reduce(0) { $0 + $1.item.byteCount }))")
            print("> ", terminator: "")
            fflush(stdout)
            guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return nil
            }
            let lower = line.lowercased()
            if lower == "q" || lower == "quit" { return nil }
            if lower.isEmpty || lower == "done" || lower == "review" {
                if sel.isEmpty {
                    print(CLITerm.yellow("Select at least one item."))
                    continue
                }
                print("")
                print(CLITerm.bold("Review — will move to Trash:"))
                for row in sel {
                    print("  \(ByteFormat.string(row.item.byteCount))\t\(row.item.url.path)")
                }
                print("Confirm? [y/N] ", terminator: "")
                fflush(stdout)
                let answer = (readLine() ?? "").trimmingCharacters(in: .whitespaces).lowercased()
                if answer == "y" || answer == "yes" {
                    return sel.map(\.item)
                }
                print("Back to selection.")
                continue
            }
            if lower == "a" {
                for i in rows.indices { rows[i].selected = true }
                continue
            }
            if lower == "n" {
                for i in rows.indices { rows[i].selected = false }
                continue
            }
            for token in line.split(whereSeparator: { $0.isWhitespace || $0 == "," }) {
                guard let n = Int(token), (1...rows.count).contains(n) else { continue }
                rows[n - 1].selected.toggle()
            }
        }
    }
}

private extension Character {
    var isASCIIControl: Bool {
        unicodeScalars.allSatisfy { $0.value < 0x20 || $0.value == 0x7F }
    }
}
