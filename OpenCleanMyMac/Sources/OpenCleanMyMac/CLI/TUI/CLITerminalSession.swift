import Darwin
import Foundation

enum CLITerminalKey: Equatable {
    case up, down, left, right
    case pageUp, pageDown, home, end
    case enter, escape, space, backspace, delete
    case character(Character)
    case unknown
}

enum CLITerminalError: Error, CustomStringConvertible {
    case unsupported
    case setupFailed

    var description: String {
        switch self {
        case .unsupported:
            return "Interactive TUI needs a real TTY (or use --plain / --dry-run)."
        case .setupFailed:
            return "Could not put the terminal into raw mode."
        }
    }
}

/// Alternate-screen raw terminal session for the MacCleaner TUI.
final class CLITerminalSession {
    static var isSupported: Bool {
        isatty(STDIN_FILENO) == 1
            && isatty(STDOUT_FILENO) == 1
            && ProcessInfo.processInfo.environment["TERM"] != "dumb"
    }

    private var closed = false
    private var saved = termios()
    private var hadSaved = false

    var width: Int { size().cols }
    var height: Int { size().rows }

    init() throws {
        guard Self.isSupported else { throw CLITerminalError.unsupported }
        var original = termios()
        guard tcgetattr(STDIN_FILENO, &original) == 0 else { throw CLITerminalError.setupFailed }
        saved = original
        hadSaved = true

        var raw = original
        cfmakeraw(&raw)
        raw.c_lflag |= tcflag_t(ISIG)
        guard tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) == 0 else {
            restore()
            throw CLITerminalError.setupFailed
        }
        writeRaw("\u{1B}[?1049h\u{1B}[?25l\u{1B}[2J\u{1B}[H")
    }

    deinit { close() }

    func draw(lines: [String]) {
        guard !closed else { return }
        let frame = lines.prefix(max(1, height)).map { "\u{1B}[2K" + $0 }.joined(separator: "\r\n")
        writeRaw("\u{1B}[H" + frame + "\u{1B}[J")
    }

    func readKey() -> CLITerminalKey {
        guard !closed, let first = readByte() else { return .escape }
        switch first {
        case 0x0A, 0x0D: return .enter
        case 0x20: return .space
        case 0x08, 0x7F: return .backspace
        case 0x1B: return readEscape()
        default: return decodeChar(first)
        }
    }

    func close() {
        guard !closed else { return }
        closed = true
        restore()
        writeRaw("\u{1B}[0m\u{1B}[?25h\u{1B}[?1049l")
    }

    private func restore() {
        guard hadSaved else { return }
        var state = saved
        _ = tcsetattr(STDIN_FILENO, TCSAFLUSH, &state)
        hadSaved = false
    }

    private func writeRaw(_ value: String) {
        let bytes = Array(value.utf8)
        bytes.withUnsafeBytes { buf in
            guard let base = buf.baseAddress else { return }
            _ = Darwin.write(STDOUT_FILENO, base, buf.count)
        }
    }

    private func readByte() -> UInt8? {
        var byte: UInt8 = 0
        while true {
            let n = Darwin.read(STDIN_FILENO, &byte, 1)
            if n == 1 { return byte }
            if n == -1 && errno == EINTR { continue }
            return nil
        }
    }

    private func available(ms: Int32) -> Bool {
        var p = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        return poll(&p, 1, ms) > 0
    }

    private func readEscape() -> CLITerminalKey {
        guard available(ms: 30), let second = readByte() else { return .escape }
        guard second == 0x5B || second == 0x4F else { return .escape }
        guard available(ms: 30), let third = readByte() else { return .escape }
        switch third {
        case 0x41: return .up
        case 0x42: return .down
        case 0x43: return .right
        case 0x44: return .left
        case 0x48: return .home
        case 0x46: return .end
        case 0x31, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38:
            guard available(ms: 30), let fourth = readByte(), fourth == 0x7E else { return .unknown }
            switch third {
            case 0x31, 0x37: return .home
            case 0x33: return .delete
            case 0x34, 0x38: return .end
            case 0x35: return .pageUp
            case 0x36: return .pageDown
            default: return .unknown
            }
        default:
            return .unknown
        }
    }

    private func decodeChar(_ first: UInt8) -> CLITerminalKey {
        let need: Int
        switch first {
        case 0x00...0x7F: need = 1
        case 0xC2...0xDF: need = 2
        case 0xE0...0xEF: need = 3
        case 0xF0...0xF4: need = 4
        default: return .unknown
        }
        var bytes = [first]
        while bytes.count < need {
            guard available(ms: 30), let b = readByte() else { return .unknown }
            bytes.append(b)
        }
        guard let s = String(bytes: bytes, encoding: .utf8), let c = s.first, s.count == 1 else {
            return .unknown
        }
        return .character(c)
    }

    private func size() -> (cols: Int, rows: Int) {
        var w = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0 else { return (80, 24) }
        return (max(1, Int(w.ws_col)), max(1, Int(w.ws_row)))
    }
}
