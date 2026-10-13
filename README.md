# MacCleaner

Native SwiftUI utility for **macOS 14+** that finds reclaimable disk space, uninstalls apps with leftovers, and runs a few maintenance tasks — all on-device.

| | |
|---|---|
| **Download** | [MacCleaner 0.2.2 (DMG)](releases/MacCleaner-0.2.2.dmg) · [ZIP](releases/MacCleaner-0.2.2.zip) |
| **Homebrew** | `brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner && brew trust mponzo/maccleaner && brew install --cask maccleaner` |
| **Site** | [mponzo.github.io/MacCleaner](https://mponzo.github.io/MacCleaner/) |
| **License** | MIT |

Universal binary (Apple silicon + Intel). UI in **English** and **Italian**.

---

## Install

**DMG**

1. Download [MacCleaner 0.2.2](releases/MacCleaner-0.2.2.dmg)  
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

Lists user apps, estimates bundle + leftover size, and finds related files under Preferences, Caches, Application Support, Logs, Saved State, Cookies, Containers, Group Containers, Launch Agents, and Crash Reporter. System apps cannot be uninstalled from here.

### Performance

Live memory / CPU / free disk, top processes, user Launch Agents, plus maintenance helpers (DNS flush, Mail VACUUM, APFS snapshot thinning, Launch Services) where elevation is required.

### Space Lens, menu bar, updates

- **Space Lens** — bar chart of categories from the last Smart Care run  
- **Menu bar** — glass status panel (disk, RAM, battery, CPU, network, activity) with shortcuts into the main window  
- **Updates** — compares this build to [`releases/version.json`](releases/version.json) on GitHub when you open the section  

### Settings

Language (System / EN / IT), menu bar icon, Dock visibility, launch at login, install/remove from `~/Applications`.

**Shortcuts:** ⌘R Smart Care · ⌘K clean selected · ⌘Q quit · ⇧⌘U refresh apps · ⇧⌘P refresh performance  

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

---

## License

[MIT](LICENSE). Contributions welcome via PR.
