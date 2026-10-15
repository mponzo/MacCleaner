import Foundation

/// Detects CLI invocations and runs ArgumentParser without opening the SwiftUI app.
enum CLIBootstrap {
    private static let subcommands: Set<String> = [
        "scan", "clean", "apps", "orphans", "doctor", "version", "help"
    ]

    private static let legacyFlags: [String: [String]] = [
        "--scan-once": ["scan"],
        "--apps-once": ["apps"],
        "--perf-once": ["doctor", "--perf"],
        "--priv-once": ["doctor", "--priv"]
    ]

    /// True when argv asks for the product CLI (or legacy headless smoke flags).
    static var isCLIInvocation: Bool {
        let exe = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? ""
        if exe == "maccleaner" { return true }

        let args = Array(CommandLine.arguments.dropFirst())
        guard let first = args.first else { return false }
        if legacyFlags[first] != nil { return true }
        if subcommands.contains(first) { return true }
        // `maccleaner --help` / `OpenCleanMyMac --help` when first token is help flag
        // only if explicitly requesting CLI help via subcommand form is preferred;
        // bare --help on the GUI binary stays unused (Finder launch has no flags).
        if first == "--help" || first == "-h" { return true }
        return false
    }

    /// Parses/remaps argv and exits. Call only when `isCLIInvocation` is true.
    static func runAndExit() -> Never {
        // ArgumentParser.main(_:) expects arguments *without* the executable name
        // when a non-nil array is passed.
        var args = Array(CommandLine.arguments.dropFirst())
        if let first = args.first, let mapped = legacyFlags[first] {
            args = mapped + Array(args.dropFirst())
        }
        MacCleanerCLI.main(args)
        Foundation.exit(0)
    }
}
