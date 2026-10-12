import Foundation

/// Scaffold for a future SMAppService privileged daemon.
/// Today the main app uses PrivilegedBridge (osascript admin). This helper is the
/// replacement endpoint once the app is bundled + signed with the same Team ID.
///
/// Expected future protocol (JSON over XPC stdin/stdout for local testing):
///   {"op":"ping"}
///   {"op":"flushDNS"}
///   {"op":"thinSnapshots"}
///   {"op":"remove","path":"/Library/Caches/..."}

struct HelperRequest: Codable {
    var op: String
    var path: String?
}

struct HelperResponse: Codable {
    var ok: Bool
    var message: String
}

@main
enum OpenCleanPrivilegedHelperMain {
    static func main() {
        let args = CommandLine.arguments
        if args.contains("--ping") {
            emit(HelperResponse(ok: true, message: "open-clean-privileged-helper scaffold \(version)"))
            return
        }

        if args.contains("--stdio") {
            runStdioLoop()
            return
        }

        emit(HelperResponse(
            ok: true,
            message: "Scaffold only. Wire SMAppService.daemon after signing. Use --ping or --stdio."
        ))
    }

    private static let version = "0.1.0"

    private static func runStdioLoop() {
        while let line = readLine(strippingNewline: true) {
            guard let data = line.data(using: .utf8),
                  let request = try? JSONDecoder().decode(HelperRequest.self, from: data)
            else {
                emit(HelperResponse(ok: false, message: "invalid request"))
                continue
            }
            emit(handle(request))
        }
    }

    private static func handle(_ request: HelperRequest) -> HelperResponse {
        switch request.op {
        case "ping":
            return HelperResponse(ok: true, message: "pong \(version)")
        case "flushDNS", "thinSnapshots", "remove":
            return HelperResponse(
                ok: false,
                message: "Not connected: install signed helper via SMAppService before executing \(request.op)."
            )
        default:
            return HelperResponse(ok: false, message: "unknown op \(request.op)")
        }
    }

    private static func emit(_ response: HelperResponse) {
        if let data = try? JSONEncoder().encode(response),
           let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
