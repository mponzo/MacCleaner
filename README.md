<p align="center">
  <img src="docs/assets/maccleaner-banner.svg" alt="MacCleaner — local cleanup, visible paths, full control" width="920"/>
</p>

<h1 align="center">MacCleaner</h1>

<p align="center">
  <strong>Reclaim space on your Mac.</strong><br/>
  Open-source, native SwiftUI cleaner: Smart Care, uninstall, performance, and maintenance.<br/>
  <strong>Zero telemetry. Zero accounts. Zero cloud.</strong> Everything stays on your Mac.
</p>

<p align="center">
  <img alt="Zero telemetry" src="https://img.shields.io/badge/telemetry-zero-2E6BD1?style=for-the-badge"/>
  <img alt="Privacy first" src="https://img.shields.io/badge/privacy-100%25%20local-0A1A33?style=for-the-badge"/>
  <img alt="MIT" src="https://img.shields.io/badge/license-MIT-FF9E48?style=for-the-badge"/>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-4DA3FF?style=flat-square"/>
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-SPM-4DA3FF?style=flat-square"/>
  <img alt="IT / EN" src="https://img.shields.io/badge/language-EN%20%7C%20IT-0A1A33?style=flat-square"/>
  <img alt="No analytics" src="https://img.shields.io/badge/analytics-none-2E6BD1?style=flat-square"/>
  <img alt="No subscription" src="https://img.shields.io/badge/subscription-none-2E6BD1?style=flat-square"/>
</p>

<p align="center">
  <a href="releases/MacCleaner-0.2.2.dmg"><strong>Download MacCleaner 0.2.2</strong></a> ·
  <a href="#verifiable-trust">Privacy</a> ·
  <a href="#features">Features</a> ·
  <a href="#installation">Install</a> ·
  <a href="#security--privileges">Security</a>
</p>

---

## Verifiable trust

A Mac cleaner can see sensitive files and ask for elevated privileges. It deserves transparency, not slogans. This is MacCleaner’s contract — and you can audit it in the source:

| Commitment | What it means |
|---|---|
| **No telemetry, ever** | No analytics, third-party crash reporters, “anonymous stats”, accounts, or phone-home. The app **does not know who you are**. |
| **No network back to us** | Scans and cleanups work **offline**. We do not upload paths, file lists, or deleted data. |
| **No fake urgency** | No red alarms like “your Mac is at risk”. Neutral sizes and paths — you decide. |
| **Explicit selection** | No blind “clean everything”. See paths, tick what to free, **Stop** anytime. |
| **Trash for user cleanups** | Selected user items go to the macOS **Trash** (`trashItem`), not a silent hidden delete. |
| **Admin only on an allowlist** | System caches/logs and similar use a password bridge and **explicitly allowed** paths. |
| **Open source (MIT)** | Readable, forkable, auditable. Adding telemetry or paywalling core features would break this contract. |

### What MacCleaner does **not** do

- Collect telemetry, crash reports, or usage analytics  
- Require an account, login, or subscription  
- Upload scanned paths or deleted files to external servers  
- Present itself as antivirus / malware scanner  
- Promise “RAM boosts” or magic APFS purgeable-space tricks  

---

## Contents

1. [Verifiable trust](#verifiable-trust)  
2. [Why MacCleaner](#why-maccleaner)  
3. [Requirements](#requirements)  
4. [Features](#features)  
5. [Interface & language](#interface--language)  
6. [Installation](#installation)  
7. [Website (GitHub Pages)](#website-github-pages)  
8. [Development & CLI](#development--cli)  
9. [Security & privileges](#security--privileges)  
10. [Roadmap](#roadmap)  
11. [License](#license)  

---

## Why MacCleaner

Many commercial cleaners hide logic behind subscriptions, telemetry, and alarmist UI. MacCleaner is the opposite:

- **One-time install** — no trial, no account  
- **Zero telemetry** — does not call home  
- **MIT open source** — read, verify, change  
- **Honest scans** — caches, leftovers, DerivedData, logs: measurable facts, not fear  
- **Real uninstalls** — Library leftovers (prefs, cache, containers, agents…) with explicit selection  

MacCleaner is **local and transparent**: every reclaimable item shows its disk path; system operations use an admin bridge with an **allowlist**.

| Principle | In practice |
|---|---|
| Local | Filesystem only; no product telemetry |
| Transparent | Sizes, paths, and categories always visible |
| Selective | Item by item — not blind “clean all” |
| Interruptible | **Stop** during Smart Care or cleanup |
| Private | No analytics, no crash phone-home |
| Bilingual | English and Italian (system or in Settings) |

---

## Requirements

- **macOS 14** (Sonoma) or later  
- Universal binary (Apple Silicon + Intel): [`MacCleaner-0.2.2.dmg`](releases/MacCleaner-0.2.2.dmg) or [`.zip`](releases/MacCleaner-0.2.2.zip)  
- Xcode / Swift only if you build from source  
- Optional: [Homebrew](https://brew.sh) for `brew install --cask`  

---

## Features

### Smart Care

Multi-category reclaimable-space scan, with you in control.

- **Run Smart Care** with per-category progress  
- Metrics: reclaimable, scanned, status  
- Clickable modules → category **detail**  
- **Clean selected** → only what you ticked, into Trash  
- **Stop** during scan or cleanup  

#### Scanned categories

| Category | What it measures | Notes |
|---|---|---|
| User caches | `~/Library/Caches` | Cleanable |
| User logs | `~/Library/Logs` | Cleanable |
| Trash | `~/.Trash` | Cleanable |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Cleanable |
| Xcode Archives | `~/Library/Developer/Xcode/Archives` | Cleanable |
| Developer caches | npm, Homebrew, pip, Gradle, Yarn, pnpm, Cargo… | Cleanable |
| Old downloads | Downloads older than 30 days | Cleanable |
| Disk images | `*.dmg` / `*.iso` in Downloads | Cleanable |
| Browser caches | Safari / Chrome / Firefox / Edge | Cleanable |
| Large folders | Top Home folders | Read-only |
| App leftovers | Orphan prefs, caches, containers | Cleanable |
| Invalid Launch Agents | User agents with missing binary | Cleanable |
| System caches | `/Library/Caches` | Admin + allowlist |
| System logs | `/Library/Logs`, `/var/log` | Admin + allowlist |
| Invalid system agents | `/Library/LaunchAgents` | Admin + allowlist |

---

### Applications

Mindful uninstall with related leftovers.

- User app list (search by name / bundle ID)  
- Bundle size + leftovers  
- Leftovers: Preferences, Caches, Application Support, Logs, Saved State, Cookies, Containers, Group Containers, Launch Agents, Crash Reporter  
- Toggle “Include app bundle”  
- **Orphan leftovers** cleanup  
- System apps protected: uninstall disabled  

---

### Performance

- Memory, CPU, free disk  
- Top processes by memory  
- Launch Agents (remove user-domain only)  
- Maintenance: DNS *(admin)*, Mail VACUUM, APFS snapshots *(admin)*, Launch Services  

---

### Privileged helper

- Admin bridge (password prompt)  
- Rescan system caches / logs / agents  
- DNS flush and snapshot thinning  
- **Allowlisted** paths only  
- Future `SMAppService` scaffold → `docs/PRIVILEGED_HELPER.md`  

---

### Space Lens

Bars for categories already scanned — where space went after Smart Care.

---

### Updates

In-app section: compare the local version with [`releases/version.json`](releases/version.json) on the repo, download the release zip, install to `~/Applications`, then relaunch. Network goes to GitHub only when you open this section or tap Check.

---

### Menu bar (one-click)

Glass status panel (not a classic menu): Mac status, disk / RAM / battery / CPU, network, activity, Smart Care tip, Open / Settings / **Quit**. Single main window — no duplicate instances.

---

### Settings

Language (System / EN / IT), menu bar, Dock, launch at login, install to `~/Applications`, **Quit**.

---

## Interface & language

**Dark blue-glass** theme. Strings in `en.lproj` / `it.lproj`.

| Shortcut | Action |
|---|---|
| ⌘R | Run Smart Care |
| ⌘K | Clean selected |
| ⌘Q | Quit |
| ⇧⌘U | Refresh applications |
| ⇧⌘P | Refresh performance |

---

## Installation

No programming required. Prefer the **DMG**, or install with **Homebrew**.

<p align="center">
  <a href="releases/MacCleaner-0.2.2.dmg">
    <img src="https://img.shields.io/badge/Download%20MacCleaner-0.2.2%20·%20DMG-2E6BD1?style=for-the-badge" alt="Download MacCleaner 0.2.2"/>
  </a>
</p>

<p align="center">
  <img src="docs/assets/install-steps.svg" alt="1 Download · 2 Install · 3 Open" width="920"/>
</p>

### DMG (recommended)

| | Action | Detail |
|:---:|---|---|
| **1** | **Download** | Get **[MacCleaner 0.2.2](releases/MacCleaner-0.2.2.dmg)** |
| **2** | **Install** | Open the DMG and drag **MacCleaner** into **Applications** |
| **3** | **Open** | Double-click **MacCleaner** in Applications |

Alternate archive: [`MacCleaner-0.2.2.zip`](releases/MacCleaner-0.2.2.zip).

### Homebrew

Yes — GUI apps install as a **cask**:

```bash
brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner
brew install --cask maccleaner
```

Upgrade later with `brew upgrade --cask maccleaner`.

Works on Apple silicon and Intel Macs.

<details>
<summary><strong>How to uninstall</strong></summary>

<br/>

Drag **MacCleaner** from Applications to the **Trash**, or:

```bash
brew uninstall --cask maccleaner
```

</details>

<details>
<summary><strong>Developer options</strong> (optional)</summary>

<br/>

**From source** (needs Xcode / Swift):

```bash
./Scripts/install.sh      # build and install to ~/Applications
./Scripts/package-app.sh  # dist app + MacCleaner-<version>.{dmg,zip} + cask
./Scripts/uninstall.sh
```

Bundle id: `com.maccleaner.app` · SPM target: `OpenCleanMyMac`.

</details>

---

## Website (GitHub Pages)

Nuxt 3 landing in the repo root (`pages/`, `nuxt.config.ts`). Workflow [`.github/workflows/nuxtjs.yml`](.github/workflows/nuxtjs.yml) runs `npm ci` + `nuxt generate` and publishes `.output/public` to **GitHub Pages**.

```bash
npm install
npm run dev          # local
npm run generate     # static export → .output/public
```

**One-time setup:** repo → **Settings → Pages → Build and deployment → Source: GitHub Actions**. Typical URL: `https://mponzo.github.io/MacCleaner/`.

---

## Development & CLI

```bash
cd OpenCleanMyMac
swift build
swift run
```

Headless (no UI, useful for local audits):

```bash
swift run OpenCleanMyMac -- --scan-once
swift run OpenCleanMyMac -- --apps-once
swift run OpenCleanMyMac -- --perf-once
swift run OpenCleanMyMac -- --priv-once
```

```text
OpenCleanMyMac/Sources/OpenCleanMyMac/
  App/  Core/  Features/  Localization/  Resources/  UI/
Scripts/   docs/
```

---

## Security & privileges

### Privacy by design

| Question | Answer |
|---|---|
| Sends data to the internet? | **No** for scan/clean (offline work) |
| Telemetry / analytics? | **No** |
| Remote crash reporter? | **No** |
| Required account? | **No** |
| Inspectable code? | **Yes** (MIT) |

### Destructive behavior

- User cleanups → macOS **Trash**  
- System → admin bridge + **allowlist**  
- Selection (checkboxes) before cleaning  
- **Stop** cancels the in-flight task  
- Not an antivirus  

If you find a security issue, report it privately (not in public issues with a PoC).

---

## Roadmap

- Signed privileged daemon (`SMAppService`) instead of osascript prompts  
- Broader scanner coverage and UI polish  
- Languages beyond EN/IT  

---

## License

**MIT.** Use, modify, redistribute. Keep the copyright notice as usual for MIT.

> If MacCleaner freed space **without** selling your data, that is exactly the point.
