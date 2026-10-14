# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

<!-- Assumption: native macOS SwiftUI utility; closest Impeccable platform tag for Apple desktop apps. -->

## Users

Mac users who want to reclaim disk space and uninstall apps safely with transparent, local-first tools.

## Product Purpose

**MacCleaner** — open-source Smart Care cleaner for macOS: scan junk/caches/leftovers, uninstall apps with related files, performance maintenance, and an admin bridge for system paths. Success = reclaim bytes with clear paths and deliberate delete actions.

## Positioning

Original open implementation. Privileged work is allowlisted and password-prompted until a signed SMAppService helper ships. No third-party trademarks in the product UI.

**Privacy contract:** zero telemetry, no analytics, no crash phone-home, no account, no cloud upload of scanned paths. Cleanup is local-first and auditable (MIT).

## Capabilities

- Smart Care multi-category scan (incl. Mail) and selective Trash moves + exclusions
- Applications leftovers, Finder Services uninstall, Orphan Finder
- Space Explorer, Startup (agents + snapshots), Developer Cleanup, Privacy hub
- Performance metrics, launch agents, maintenance tasks; dedicated Homebrew App Updates + MacCleaner self-update
- Privileged admin bridge for system caches/logs/DNS/snapshots
- Menu bar one-click status panel + launch at login
- UI: EN / IT / DE / FR / ES / pt-BR / JA / zh-Hans / EL / RU (system or user-chosen)
- Nested category detail / Performance→Startup include a Back control
- Cleanup History with local share card (no upload) + animated reclaim / meter charts

## Constraints

- macOS 14+, SwiftUI SPM executable packaged as MacCleaner.app
- Fixed dark blue-glass appearance
- Destructive actions must stay explicit and path-visible
- No invented malware-protection claims

## Voice

Direct, calm, technical-but-plain. Prefer concrete sizes and paths over hype.

## Open decisions

- Signed SMAppService privileged helper not yet shipped (scaffold only)
