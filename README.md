# MacCleaner

Native SwiftUI utility for **macOS 14+** that finds reclaimable disk space, uninstalls apps with leftovers, explores disk use, finds duplicates and similar photos, and can schedule Smart Care — all on-device.

| | |
|---|---|
| **Download** | [MacCleaner 0.2.8 (DMG)](https://github.com/mponzo/MacCleaner/releases/download/v0.2.8/MacCleaner-0.2.8.dmg) · [ZIP](https://github.com/mponzo/MacCleaner/releases/download/v0.2.8/MacCleaner-0.2.8.zip) · [Releases](https://github.com/mponzo/MacCleaner/releases) |
| **Homebrew** | `brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner && brew trust mponzo/maccleaner && brew install --cask maccleaner` |
| **Site** | [mponzo.github.io/MacCleaner](https://mponzo.github.io/MacCleaner/) |
| **License** | MIT |

Universal binary (Apple silicon + Intel). UI in **English, Italian, German, French, Spanish, Portuguese (Brazil), Japanese, and Simplified Chinese**.

---

## Install

**DMG**

1. Download [MacCleaner 0.2.8](https://github.com/mponzo/MacCleaner/releases/download/v0.2.8/MacCleaner-0.2.8.dmg)  
2. Open the disk image and drag the app into **Applications**  
3. Launch MacCleaner  

Builds from **v0.2.5+** are **Developer ID signed + notarized**. Gatekeeper should open the DMG/app without the “Apple cannot verify” dialog.

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

Runs a multi-category scan and lets you pick what to free. Progress is per category; you can **Stop** mid-scan or mid-clean. Selected user items go to the **Trash**. Paths can be **excluded** from future cleans (Settings or from category detail).

| Category | Location / notes |
|---|---|
| User caches & logs | `~/Library/Caches`, `~/Library/Logs` |
| Trash | `~/.Trash` |
| Xcode | DerivedData, Archives |
| Dev tool caches | npm, Homebrew, pip, Gradle, Yarn, pnpm, Cargo… |
| Downloads | Files older than 30 days; `*.dmg` / `*.iso` |
| Browsers | Safari, Chrome, Firefox, Edge caches |
| Mail | Mail Downloads; MailData under `~/Library/Mail` |
| Leftovers / agents | Orphan prefs & containers; broken user Launch Agents |
| Large folders | Top folders under Home (measure only) |
| System (optional) | `/Library/Caches`, logs, system agents — password + path allowlist |

### Applications

Lists user apps, estimates bundle + leftover size, and finds related files under Preferences, Caches, Application Support, Logs, Saved State, Cookies, Containers, Group Containers, Launch Agents, and Crash Reporter. System apps cannot be uninstalled from here. Bundles under `/Applications` use Finder recycle with an admin fallback when needed.

**Finder → Services → Uninstall with MacCleaner** sends a selected `.app` into the same uninstall flow.

### Orphan Finder

Scans Library leftovers whose bundle ID no longer matches an installed app, then lets you select and Trash them — dedicated hub for post-uninstall debris.

### Duplicate Finder

Pick a folder; MacCleaner groups **exact** copies by size + SHA-256. Hard links collapse to one entry. Each group keeps one **protected** copy; you choose which extras go to the Trash. Packages, symlinks, and hidden items are skipped.

### Similar Photos

Visual estimate from **local thumbnails** only (up to 500 photos / 10,000 directory entries). Groups likely matches for side-by-side review and **Reveal in Finder**. Photos are never deleted or uploaded — similarity is an estimate, not proof of identity.

### Startup

User Launch Agents (flag broken ones, remove selected from the user domain) plus local **Time Machine / APFS snapshots** you can thin selectively.

### Developer Cleanup

Focused reclaim of common toolchain caches (Xcode DerivedData/Archives, npm, Homebrew, pip, Gradle, and similar) with selective Trash moves.

### Space Explorer

Interactive folder browser: pick Home, Applications, or any directory, drill into children with sizes, and open paths in Finder. Replaces the old chart-only Space Lens view.

### Privacy

Read-only overview of **APFS purgeable** space (optional thin-snapshots helper), a **TCC permission inventory** for your user domain, Full Disk Access status, and deep links into System Settings / browser privacy panes. No silent permission changes.

### Schedule

Optional background Smart Care while the app stays in the menu bar. Choose an interval (hourly → monthly), optionally **auto-clean** when reclaimable space meets a MB threshold, and run a cycle immediately from Settings.

### Performance

Live memory / CPU / free disk, memory pressure and uptime, top processes, user Launch Agents, plus maintenance helpers (DNS flush, Mail VACUUM, APFS snapshot thinning, Launch Services, open Activity Monitor) where elevation is required.

### Updates

Compares this build to [`releases/version.json`](releases/version.json) / GitHub Releases when you open the section. Also lists **outdated Homebrew casks** (when `brew` is installed) and can upgrade selected casks.

### Menu bar

Glass status panel (disk, RAM, battery, CPU, network, activity). Closing the main window keeps the app in the menu bar.

### Onboarding & Settings

First launch walks through **Full Disk Access** (open System Settings, recheck, continue). Settings also show FDA status, FileVault / Gatekeeper read-only status, language (System / EN / IT / DE / FR / ES / pt-BR / JA / zh-Hans), cleanup **exclusions**, menu bar / Dock, launch at login, and install/remove from `~/Applications`. Full quit is **Settings → Quit** only.

**Shortcuts:** ⌘R Smart Care · ⌘K clean selected · ⇧⌘U refresh apps · ⇧⌘P refresh performance  

---

## How cleanup behaves

MacCleaner is built so you can see the path before anything moves:

- Scans and cleanup work **offline** (updates only contact GitHub when you ask; Homebrew cask checks use local `brew`)  
- No accounts, subscriptions, or product analytics  
- User cleanup uses `trashItem` (macOS Trash), not a silent wipe  
- Elevated system paths go through an admin prompt and an **allowlist**  
- Not positioned as antivirus or a “RAM / purgeable space booster”  

Privileged-helper notes: [`docs/PRIVILEGED_HELPER.md`](docs/PRIVILEGED_HELPER.md).

---

## Build from source

Needs Xcode / Swift toolchain.

```bash
pip3 install --user dmgbuild   # branded DMG window (background + icon layout)
./Scripts/package-app.sh       # → dist/MacCleaner.app + releases/MacCleaner-<version>.{dmg,zip}
./Scripts/install.sh           # copy into ~/Applications
```

Regenerate the DMG artwork (optional): `python3 Scripts/render-dmg-background.py`

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

---

## License

[MIT](LICENSE). Contributions welcome via PR.
