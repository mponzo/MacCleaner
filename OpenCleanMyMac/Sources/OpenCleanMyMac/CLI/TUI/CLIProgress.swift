import Darwin
import Foundation

/// Animated green progress bar for long CLI operations (scan, orphan discovery, …).
final class CLIProgress {
    private let title: String
    private let total: Int
    private let width: Int
    private var current = 0
    private var detail = ""
    private var tick = 0
    private var finished = false
    private var animator: Task<Void, Never>?
    private let lock = NSLock()
    private let interactive: Bool

    init(title: String, total: Int, barWidth: Int = 28) {
        self.title = title
        self.total = max(1, total)
        self.width = max(10, barWidth)
        self.interactive = isatty(STDOUT_FILENO) == 1
            && ProcessInfo.processInfo.environment["TERM"] != "dumb"
    }

    /// Starts the shimmer animation and draws the initial frame.
    func start(detail: String = "") {
        lock.lock()
        self.detail = detail
        finished = false
        lock.unlock()
        render()
        guard interactive else { return }
        animator = Task.detached(priority: .utility) { [weak self] in
            while let self, !Task.isCancelled {
                self.lock.lock()
                let done = self.finished
                self.lock.unlock()
                if done { break }
                self.lock.lock()
                self.tick &+= 1
                self.lock.unlock()
                self.render()
                try? await Task.sleep(nanoseconds: 90_000_000)
            }
        }
    }

    /// Advances the determinate fill (0…total).
    func update(step: Int, detail: String) {
        lock.lock()
        current = min(total, max(0, step))
        self.detail = detail
        lock.unlock()
        render()
    }

    /// Clears the live line and optionally prints a completion message.
    func finish(_ message: String? = nil) {
        lock.lock()
        finished = true
        current = total
        lock.unlock()
        animator?.cancel()
        animator = nil
        if interactive {
            fputs("\r\u{1B}[2K", stdout)
        }
        if let message {
            fputs(message + "\n", stdout)
        }
        fflush(stdout)
    }

    deinit {
        animator?.cancel()
    }

    // MARK: - Render

    private func render() {
        lock.lock()
        let cur = current
        let tot = total
        let t = tick
        let label = detail
        let done = finished
        lock.unlock()
        guard !done else { return }

        let fraction = Double(cur) / Double(tot)
        let filled = Int((Double(width) * fraction).rounded(.down))
        let bar = Self.greenBar(filled: filled, width: width, tick: t)
        let pct = Int((fraction * 100).rounded())
        let status = label.isEmpty ? title : "\(title) · \(label)"
        let line = "\(bar)  \(String(format: "%3d", pct))%  \(CLITerm.dim(CLITerm.truncate(status, to: 48)))"

        if interactive {
            fputs("\r\u{1B}[2K" + line, stdout)
        } else if cur == 0 || cur == tot || cur % max(1, tot / 5) == 0 {
            fputs(line + "\n", stdout)
        }
        fflush(stdout)
    }

    /// Bright green filled blocks with a soft shimmer on the leading edge.
    private static func greenBar(filled: Int, width: Int, tick: Int) -> String {
        let safeFilled = min(width, max(0, filled))
        var cells: [String] = []
        cells.reserveCapacity(width)
        for i in 0..<width {
            if i < safeFilled {
                // Pulse the newest filled cell so the bar feels alive between steps.
                let isHead = i == safeFilled - 1 && safeFilled < width
                let pulse = isHead && (tick % 2 == 0)
                let block = pulse ? "▓" : "█"
                cells.append(CLITerm.style(block, "32;1"))
            } else {
                // Subtle traveling highlight in the empty track.
                let wave = (i + tick) % max(4, width / 3) == 0
                cells.append(CLITerm.style(wave ? "░" : "·", "32;2"))
            }
        }
        let open = CLITerm.style("[", "32")
        let close = CLITerm.style("]", "32")
        return open + cells.joined() + close
    }
}

extension CLIScan {
    /// Scan with a live green progress bar on stdout.
    static func collectWithProgress(
        categories: Set<ScanCategory>?,
        title: String = "Scanning"
    ) async -> [CategoryResult] {
        let scanners = ScannerRegistry.all.filter { scanner in
            guard let categories else { return true }
            return categories.contains(scanner.category)
        }
        let progress = CLIProgress(title: title, total: max(1, scanners.count))
        progress.start(detail: "starting")
        defer { progress.finish() }

        var results: [CategoryResult] = []
        for (index, scanner) in scanners.enumerated() {
            if CLISupport.cancelled { break }
            progress.update(step: index, detail: scanner.category.rawValue)
            let items = await scanner.scan()
            let exclusions = CLISupport.exclusionPaths()
            let filtered = items.filter { !CLISupport.isExcluded($0.url, paths: exclusions) }
            results.append(CategoryResult(category: scanner.category, items: filtered))
            progress.update(step: index + 1, detail: scanner.category.rawValue)
        }
        results.sort { $0.totalBytes > $1.totalBytes }
        return results
    }
}
