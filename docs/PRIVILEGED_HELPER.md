# Privileged helper

MacCleaner currently uses an allowlisted admin bridge (`osascript` password prompt) for operations that need elevation (system caches/logs, DNS flush, snapshot thinning).

Roadmap for a signed helper:

1. Package MacCleaner as a real `.app` bundle
2. Add `OpenCleanPrivilegedHelper` (or rename) as an SMAppService daemon
3. Sign app + helper with the same Team ID
4. Replace osascript prompts with XPC to the daemon

See `Tools/OpenCleanPrivilegedHelper/` for the scaffold.
