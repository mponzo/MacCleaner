import Darwin
import Foundation

enum CLITerm {
    private static let localeConfigured: Void = {
        setlocale(LC_CTYPE, "")
    }()

    static var colorEnabled: Bool {
        ProcessInfo.processInfo.environment["NO_COLOR"] == nil
            && ProcessInfo.processInfo.environment["TERM"] != "dumb"
            && isatty(fileno(stdout)) == 1
    }

    static func style(_ string: String, _ codes: String) -> String {
        colorEnabled ? "\u{1B}[\(codes)m\(string)\u{1B}[0m" : string
    }

    static func bold(_ string: String) -> String { style(string, "1") }
    static func dim(_ string: String) -> String { style(string, "2") }
    static func cyan(_ string: String) -> String { style(string, "36") }
    static func yellow(_ string: String) -> String { style(string, "33") }
    static func green(_ string: String) -> String { style(string, "32") }
    static func inverse(_ string: String) -> String { style(string, "7") }

    static func displayWidth(_ string: String) -> Int {
        _ = localeConfigured
        var width = 0
        var escape = 0
        for scalar in string.unicodeScalars {
            if escape == 1 {
                escape = scalar.value == 0x5B ? 2 : 0
                continue
            }
            if escape == 2 {
                if (0x40...0x7E).contains(scalar.value) { escape = 0 }
                continue
            }
            if scalar.value == 0x1B {
                escape = 1
                continue
            }
            let w = wcwidth(wchar_t(scalar.value))
            width += w > 0 ? Int(w) : 0
        }
        return width
    }

    static func pad(_ string: String, to width: Int) -> String {
        string + String(repeating: " ", count: max(0, width - displayWidth(string)))
    }

    static func truncate(_ string: String, to width: Int, middle: Bool = false) -> String {
        let safe = sanitize(string)
        guard width > 0 else { return "" }
        guard displayWidth(safe) > width else { return safe }
        guard width > 1 else { return "…" }
        if middle {
            let left = (width - 1) / 2
            let right = width - 1 - left
            return prefix(safe, width: left) + "…" + suffix(safe, width: right)
        }
        return prefix(safe, width: width - 1) + "…"
    }

    static func sanitize(_ string: String) -> String {
        var out = ""
        out.reserveCapacity(string.count)
        for scalar in string.unicodeScalars {
            switch scalar.value {
            case 0x09:
                out.append(" ")
            case 0x20...0x7E, 0xA0...0x10FFFF:
                if (0x7F...0x9F).contains(scalar.value) {
                    out.append("?")
                } else {
                    out.unicodeScalars.append(scalar)
                }
            default:
                out.append("?")
            }
        }
        return out
    }

    static func shortenPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private static func prefix(_ string: String, width: Int) -> String {
        var out = ""
        var used = 0
        for ch in string {
            let w = displayWidth(String(ch))
            guard used + w <= width else { break }
            out.append(ch)
            used += w
        }
        return out
    }

    private static func suffix(_ string: String, width: Int) -> String {
        var chars: [Character] = []
        var used = 0
        for ch in string.reversed() {
            let w = displayWidth(String(ch))
            guard used + w <= width else { break }
            chars.append(ch)
            used += w
        }
        return String(chars.reversed())
    }
}
