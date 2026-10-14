# MacCleaner

Native SwiftUI utility for **macOS 14+** that finds reclaimable disk space, uninstalls apps with leftovers, explores disk use, cleans developer/AI toolchains, finds duplicates and similar photos, monitors system resources, and can schedule Smart Care — all on-device.

| | |
|---|---|
| **Download** | [MacCleaner 0.3.0 (DMG)](https://github.com/mponzo/MacCleaner/releases/download/v0.3.0/MacCleaner-0.3.0.dmg) · [ZIP](https://github.com/mponzo/MacCleaner/releases/download/v0.3.0/MacCleaner-0.3.0.zip) · [Releases](https://github.com/mponzo/MacCleaner/releases) |
| **Homebrew** | `brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner && brew trust mponzo/maccleaner && brew install --cask maccleaner` |
| **Site** | [mponzo.github.io/MacCleaner](https://mponzo.github.io/MacCleaner/) |
| **License** | MIT |

Universal binary (Apple silicon + Intel). UI in **English, Italian, German, French, Spanish, Portuguese (Brazil), Japanese, Simplified Chinese, Greek, and Russian**.

---

## Install

**DMG**

1. Download [MacCleaner 0.3.0](https://github.com/mponzo/MacCleaner/releases/download/v0.3.0/MacCleaner-0.3.0.dmg)  
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
| AI app data | Ollama, LM Studio, Hugging Face caches (**never auto-selected**) |
| Downloads | Files older than 30 days; `*.dmg` / `*.iso` |
| Browsers | Safari, Chrome, Firefox, Edge caches |
| Mail | Mail Downloads; MailData under `~/Library/Mail` |
| Large & old files | Downloads / Documents / Desktop — **>100 MB** or **older than 1 year** (never auto-selected) |
| Leftovers / agents | Orphan prefs & containers; broken user Launch Agents |
| Large folders | Top folders under Home (measure only) |
| System (optional) | `/Library/Caches`, logs, system agents — password + path allowlist |

### Applications

Lists user apps, estimates bundle + leftover size, and finds related files under Preferences, Caches, Application Support, Logs, Saved State, Cookies, Containers, Group Containers, Launch Agents, Crash Reporter, HTTPStorages, WebKit, and Application Scripts. Matching sensitivity is **Strict / Enhanced / Deep** (Team ID, vendor prefixes, Spotlight under `~/Library` on Deep). System apps cannot be uninstalled from here. Bundles under `/Applications` use Finder recycle with an admin fallback when needed.

**Drag a `.app` onto the Applications view**, or use **Finder → Services → Uninstall with MacCleaner**, to open the same review flow.

### Orphan Finder

Scans Library leftovers whose bundle ID no longer matches an installed app, then lets you select and Trash them — dedicated hub for post-uninstall debris.

### Duplicate Finder

Pick a folder; MacCleaner groups **exact** copies by size + SHA-256. Hard links collapse to one entry. Each group keeps one **protected** copy; you choose which extras go to the Trash. Packages, symlinks, and hidden items are skipped.

### Similar Photos

Visual estimate from **local thumbnails** only (up to 500 photos / 10,000 directory entries). Groups likely matches for side-by-side review and **Reveal in Finder**. Photos are never deleted or uploaded — similarity is an estimate, not proof of identity.

### Startup

User Launch Agents (flag broken ones, remove selected from the user domain) plus local **Time Machine / APFS snapshots** you can thin selectively.

### Developer Cleanup

Focused reclaim of toolchain caches (Xcode DerivedData/Archives, Core Simulator, npm, Homebrew, pip, Gradle, and similar) plus:

- **Simulator runtimes** via `simctl` (permanent delete, never auto-selected)
- **Docker** data folders and optional `docker builder prune` when Docker is installed
- **AI tools** — Ollama / LM Studio folders (also listed in Smart Care as AI App Data)

Folder targets go to the Trash; `simctl` / Docker prune actions are permanent and labeled as such.

### Space Explorer

Interactive folder browser: pick Home, Applications, or any directory, drill into children with sizes, and open paths in Finder. Replaces the old chart-only Space Lens view.

### Privacy

Read-only overview of **APFS purgeable** space (optional thin-snapshots helper), a **TCC permission inventory** for your user domain, Full Disk Access status, and deep links into System Settings / browser privacy panes. No silent permission changes.

### Cleanup History

Local-only log of successful cleanups (Smart Care, Schedule, uninstall, orphans, duplicates, developer, startup, System Monitor). Shows lifetime / 30-day totals, a **14-day freed-space chart**, and a **share card** you can export or copy as text — nothing is uploaded.

### Schedule

Optional background Smart Care while the app stays in the menu bar. Choose an interval (hourly → monthly), optionally **auto-clean** when reclaimable space meets a MB threshold, and run a cycle immediately from Settings.

### System Monitor (Performance)

Live **System Monitor** aligned with common cleaner apps:

- Host CPU / memory / disk / uptime with correct CPU **delta** sampling  
- Apps & processes with **icons**, live **CPU%**, memory, **search**, **sort** (CPU / memory / name), and **helper grouping**  
- Option to show all user apps/processes (system processes stay in Activity Monitor)  
- Maintenance helpers (DNS flush, Mail VACUUM, APFS snapshot thinning, Launch Services) and a link to Startup  

The menu bar glass panel continues to show live meters while MacCleaner stays resident.

### App Updates

Dedicated sidebar for **outdated Homebrew casks** (when `brew` is installed): review versions, select which apps to upgrade, stop mid-batch, and open Mac App Store updates for apps Homebrew does not manage.

### Updates

Compares this MacCleaner build to [`releases/version.json`](releases/version.json) / GitHub Releases. Includes a compact Homebrew cask summary with a link to the full App Updates screen.

### Menu bar

Glass status panel (disk, RAM, battery, CPU, network, activity). Closing the main window keeps the app in the menu bar.

### Onboarding & Settings

First launch walks through **Full Disk Access** (open System Settings, recheck, continue). Settings also show FDA status, FileVault / Gatekeeper read-only status, language (System / EN / IT / DE / FR / ES / pt-BR / JA / zh-Hans / EL / RU), cleanup **exclusions**, menu bar / Dock, launch at login, and install/remove from `~/Applications`. Full quit is **Settings → Quit** only. Category detail (and Startup when opened from Performance) include a **Back** control.

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

Planned in roughly this order (CLI first, then the high-value list we are tracking):

1. **CLI** with `--dry-run` (and a productized `maccleaner` command surface on top of today’s headless smoke flags)
2. **Privileged helper** via signed `SMAppService` (replace interactive password prompts for allowlisted system paths)
3. **Smart Care result filters** — path search, size/age filters, select-visible, exclude from context menu
4. **Protection hub** — Firewall / SIP / XProtect / Gatekeeper as a config audit (not antivirus)
5. **FDA retry** after grant — re-run the batch that failed without Full Disk Access
6. **Orphan ignore list** — persistent skip for false-positive leftovers
7. **Empty Trash on external volumes** (opt-in)

Later / niche:

- Modern Login Items (System Settings)
- In-app DMG auto-update
- Hidden-files browser

Explicitly out of scope: RAM boosters, reclaiming purgeable space as “junk”, and fake malware / FUD claims.

---

## License

[MIT](LICENSE). Contributions welcome via PR.
