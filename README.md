# MacCleaner

Native SwiftUI utility for **macOS 14+** that finds reclaimable disk space, uninstalls apps with leftovers, finds duplicates and similar photos, and can schedule Smart Care — all on-device.

| | |
|---|---|
| **Download** | [MacCleaner 0.2.4 (DMG)](https://github.com/mponzo/MacCleaner/releases/download/v0.2.4/MacCleaner-0.2.4.dmg) · [ZIP](https://github.com/mponzo/MacCleaner/releases/download/v0.2.4/MacCleaner-0.2.4.zip) · [Releases](https://github.com/mponzo/MacCleaner/releases) |
| **Homebrew** | `brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner && brew trust mponzo/maccleaner && brew install --cask maccleaner` |
| **Site** | [mponzo.github.io/MacCleaner](https://mponzo.github.io/MacCleaner/) |
| **License** | MIT |

Universal binary (Apple silicon + Intel). UI in **English** and **Italian**.

---

## Install

**DMG**

1. Download [MacCleaner 0.2.4](https://github.com/mponzo/MacCleaner/releases/download/v0.2.4/MacCleaner-0.2.4.dmg)  
2. Open the disk image and drag the app into **Applications**  
3. Launch MacCleaner  

**Homebrew**

```bash
brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner
brew trust mponzo/maccleaner
brew install --cask maccleaner
```

```bash
brew upgrade --cask maccleaner   # later
brew uninstall --cask maccleaner # remove
```

---

## What you get

### Smart Care

Runs a multi-category scan and lets you pick what to free. Progress is per category; you can **Stop** mid-scan or mid-clean. Selected user items go to the **Trash**.

| Category | Location / notes |
|---|---|
| User caches & logs | `~/Library/Caches`, `~/Library/Logs` |
| Trash | `~/.Trash` |
| Xcode | DerivedData, Archives |
| Dev tool caches | npm, Homebrew, pip, Gradle, Yarn, pnpm, Cargo… |
| Downloads | Files older than 30 days; `*.dmg` / `*.iso` |
| Browsers | Safari, Chrome, Firefox, Edge caches |
| Leftovers / agents | Orphan prefs & containers; broken user Launch Agents |
| Large folders | Top folders under Home (measure only) |
| System (optional) | `/Library/Caches`, logs, system agents — password + path allowlist |

### Applications

Lists user apps, estimates bundle + leftover size, and finds related files under Preferences, Caches, Application Support, Logs, Saved State, Cookies, Containers, Group Containers, Launch Agents, and Crash Reporter. System apps cannot be uninstalled from here. Bundles under `/Applications` use Finder recycle with an admin fallback when needed.

### Duplicate Finder

Pick a folder; MacCleaner groups **exact** copies by size + SHA-256. Hard links collapse to one entry. Each group keeps one **protected** copy; you choose which extras go to the Trash. Packages, symlinks, and hidden items are skipped.

### Similar Photos

Visual estimate from **local thumbnails** only (up to 500 photos / 10,000 directory entries). Groups likely matches for side-by-side review and **Reveal in Finder**. Photos are never deleted or uploaded — similarity is an estimate, not proof of identity.

### Schedule

Optional background Smart Care while the app stays in the menu bar. Choose an interval (hourly → monthly), optionally **auto-clean** when reclaimable space meets a MB threshold, and run a cycle immediately from Settings.

### Performance

Live memory / CPU / free disk, top processes, user Launch Agents, plus maintenance helpers (DNS flush, Mail VACUUM, APFS snapshot thinning, Launch Services) where elevation is required.

### Space Lens, menu bar, updates

- **Space Lens** — bar chart of categories from the last Smart Care run  
- **Menu bar** — glass status panel (disk, RAM, battery, CPU, network, activity); closing the main window keeps the app in the menu bar  
- **Updates** — compares this build to [`releases/version.json`](releases/version.json) / GitHub Releases when you open the section  

### Onboarding & Settings

First launch walks through **Full Disk Access** (open System Settings, recheck, continue). Settings also show FDA status, FileVault / Gatekeeper read-only status, language (System / EN / IT), menu bar / Dock, launch at login, and install/remove from `~/Applications`. Full quit is **Settings → Quit** only.

**Shortcuts:** ⌘R Smart Care · ⌘K clean selected · ⇧⌘U refresh apps · ⇧⌘P refresh performance  

---

## How cleanup behaves

MacCleaner is built so you can see the path before anything moves:

- Scans and cleanup work **offline** (updates only contact GitHub when you ask)  
- No accounts, subscriptions, or product analytics  
- User cleanup uses `trashItem` (macOS Trash), not a silent wipe  
- Elevated system paths go through an admin prompt and an **allowlist**  
- Not positioned as antivirus or a “RAM / purgeable space booster”  

Privileged-helper notes: [`docs/PRIVILEGED_HELPER.md`](docs/PRIVILEGED_HELPER.md).

---

## Build from source

Needs Xcode / Swift toolchain.

```bash
./Scripts/package-app.sh   # → dist/MacCleaner.app + releases/MacCleaner-<version>.{dmg,zip}
./Scripts/install.sh       # copy into ~/Applications
```

Or run the SPM target directly:

```bash
cd OpenCleanMyMac
swift build
swift run
```

Headless smoke checks (no UI):

```bash
swift run OpenCleanMyMac -- --scan-once
swift run OpenCleanMyMac -- --apps-once
swift run OpenCleanMyMac -- --perf-once
swift run OpenCleanMyMac -- --priv-once
```

```text
OpenCleanMyMac/Sources/OpenCleanMyMac/
  App/  Core/  Features/  Localization/  Resources/  UI/
Scripts/   Casks/   docs/   releases/
```

Bundle id: `com.maccleaner.app` · SPM product: `OpenCleanMyMac`.

Landing site (Nuxt → GitHub Pages): `npm install && npm run generate` — see [`.github/workflows/nuxtjs.yml`](.github/workflows/nuxtjs.yml).

---

## Roadmap

- Signed `SMAppService` helper instead of password prompts for system paths  
- Wider scanner coverage and UI polish  
- More locales beyond EN/IT  
- Finder Services “Uninstall with MacCleaner” (parity with common cleaners)  

---

## License

[MIT](LICENSE). Contributions welcome via PR.
