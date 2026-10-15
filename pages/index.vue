<script setup lang="ts">
const version = '0.3.0'
const siteUrl = 'https://mponzo.github.io/MacCleaner'
const dmgUrl = `https://github.com/mponzo/MacCleaner/releases/download/v${version}/MacCleaner-${version}.dmg`
const zipUrl = `https://github.com/mponzo/MacCleaner/releases/download/v${version}/MacCleaner-${version}.zip`
const repoUrl = 'https://github.com/mponzo/MacCleaner'
const brewCommands = `brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner
brew trust mponzo/maccleaner
brew install --cask maccleaner`
const brewDisplay = 'brew install --cask maccleaner'
const cliBrewDisplay = './Scripts/install-cli.sh'
const cliInstallCommands = `./Scripts/install-cli.sh
maccleaner --version`
const cliBrewAltCommands = `brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner
brew install --HEAD maccleaner-cli`
const cliUpgradeCommands = `brew upgrade --fetch-HEAD maccleaner-cli
brew uninstall maccleaner-cli`
const cliCloneCommands = `./Scripts/install-cli.sh
maccleaner --version`
const cliUsageCommands = `maccleaner                 # interactive workspace (TTY)
maccleaner clean           # select → review → type yes → Trash
maccleaner orphans         # orphan leftovers (TTY)
maccleaner --plain         # numbered prompts
maccleaner doctor
maccleaner scan --json
maccleaner clean --dry-run
maccleaner clean --confirm
maccleaner apps --leftovers`

const brewCopied = ref(false)
const brewCopiedInstall = ref(false)
const cliInstallCopied = ref(false)
const cliUsageCopied = ref(false)
const cliCloneCopied = ref(false)
const cliHeroCopied = ref(false)
let brewCopiedTimer: ReturnType<typeof setTimeout> | undefined

async function copyText(value: string) {
  try {
    await navigator.clipboard.writeText(value)
  } catch {
    const ta = document.createElement('textarea')
    ta.value = value
    ta.setAttribute('readonly', '')
    ta.style.position = 'fixed'
    ta.style.opacity = '0'
    document.body.appendChild(ta)
    ta.select()
    document.execCommand('copy')
    document.body.removeChild(ta)
  }
}

async function copyBrewCommands(target: 'hero' | 'install' = 'hero') {
  await copyText(brewCommands)
  if (target === 'install') {
    brewCopiedInstall.value = true
  } else {
    brewCopied.value = true
  }
  clearTimeout(brewCopiedTimer)
  brewCopiedTimer = setTimeout(() => {
    brewCopied.value = false
    brewCopiedInstall.value = false
  }, 1800)
}

function flashCopied(flag: { value: boolean }) {
  flag.value = true
  setTimeout(() => {
    flag.value = false
  }, 1800)
}

async function copyCliInstall() {
  await copyText(cliInstallCommands)
  flashCopied(cliInstallCopied)
}

async function copyCliUsage() {
  await copyText(cliUsageCommands)
  flashCopied(cliUsageCopied)
}

async function copyCliClone() {
  await copyText(cliBrewAltCommands)
  flashCopied(cliCloneCopied)
}

async function copyCliHero() {
  await copyText(cliInstallCommands)
  flashCopied(cliHeroCopied)
}

const pageTitle = 'MacCleaner — open-source Mac cleaner, zero telemetry'
const pageDescription =
  'Free open-source Mac cleaner for macOS 14+. Smart Care, interactive maccleaner CLI/TUI, Cleanup History, App Updates, Space Explorer, System Monitor, Developer Cleanup. Fully local, zero telemetry, MIT.'

const roadmapNext = [
  {
    title: 'Privileged helper (SMAppService)',
    body: 'Signed helper instead of interactive password prompts for allowlisted system paths.',
  },
  {
    title: 'CLI release + notarize',
    body: 'Publish cli-v* tarball for brew install maccleaner-cli (formula already in-tree).',
  },
  {
    title: 'Smart Care result filters',
    body: 'Path search, size/age filters, select-visible, exclude from the context menu.',
  },
  {
    title: 'Protection hub',
    body: 'Firewall / SIP / XProtect / Gatekeeper as a config audit — not antivirus.',
  },
  {
    title: 'FDA retry after grant',
    body: 'Re-run the batch that failed without Full Disk Access once access is granted.',
  },
  {
    title: 'Orphan ignore list',
    body: 'Persistently skip false-positive leftovers.',
  },
  {
    title: 'Empty Trash on external volumes',
    body: 'Opt-in emptying of Trash on external disks.',
  },
]

const roadmapLater = [
  'Modern Login Items (System Settings)',
  'In-app DMG auto-update',
  'Hidden-files browser',
]

const recentlyShipped = [
  'CLI — ./Scripts/install-cli.sh + maccleaner-cli formula (TUI)',
  'App Updates — dedicated Homebrew cask upgrades + App Store shortcut',
  'Progress bars with Stop on scans and cleans (where safe)',
  'Cleanup History — local log, 14-day chart, shareable card (no upload)',
  'Animated reclaim ribbons and System Monitor / menu bar meters',
  'System Monitor parity — CPU deltas, icons, search/sort, helper grouping',
  'Deeper uninstall — Strict / Enhanced / Deep + drag-and-drop .app',
  'Developer Cleanup — Simulator runtimes, Docker, AI app caches',
  '10 languages including Greek and Russian',
]

useSeoMeta({
  title: pageTitle,
  description: pageDescription,
  ogTitle: pageTitle,
  ogDescription: pageDescription,
  ogType: 'website',
  ogUrl: `${siteUrl}/`,
  ogImage: `${siteUrl}/icon.png`,
  ogImageAlt: 'MacCleaner app icon',
  twitterCard: 'summary_large_image',
  twitterTitle: pageTitle,
  twitterDescription: pageDescription,
  twitterImage: `${siteUrl}/icon.png`,
})

useHead({
  link: [{ rel: 'canonical', href: `${siteUrl}/` }],
  script: [
    {
      type: 'application/ld+json',
      children: JSON.stringify({
        '@context': 'https://schema.org',
        '@graph': [
          {
            '@type': 'SoftwareApplication',
            name: 'MacCleaner',
            applicationCategory: 'UtilitiesApplication',
            operatingSystem: 'macOS 14+',
            softwareVersion: version,
            license: 'https://opensource.org/licenses/MIT',
            downloadUrl: dmgUrl,
            installUrl: dmgUrl,
            url: `${siteUrl}/`,
            image: `${siteUrl}/icon.png`,
            description: pageDescription,
            offers: {
              '@type': 'Offer',
              price: '0',
              priceCurrency: 'USD',
            },
            featureList: [
              'Smart Care multi-category disk cleanup',
              'Application uninstaller with leftovers',
              'Space Explorer',
              'Scheduled Smart Care',
              'System Monitor',
              'Developer Cleanup',
              'Zero telemetry',
            ],
          },
          {
            '@type': 'WebSite',
            name: 'MacCleaner',
            url: `${siteUrl}/`,
            description: pageDescription,
            inLanguage: 'en',
          },
          {
            '@type': 'Organization',
            name: 'MacCleaner',
            url: repoUrl,
          },
        ],
      }),
    },
  ],
})

const promises = [
  {
    title: 'Zero telemetry',
    body: 'No analytics, crash reporters, or phone-home. The app does not know who you are.',
  },
  {
    title: 'Fully local',
    body: 'Scans and cleanups work offline. Your paths never leave your Mac.',
  },
  {
    title: 'Visible paths',
    body: 'See what would be freed, select it yourself, stop anytime.',
  },
]

type Motif =
  | 'scan'
  | 'apps'
  | 'orphans'
  | 'dupes'
  | 'photos'
  | 'startup'
  | 'dev'
  | 'space'
  | 'privacy'
  | 'schedule'
  | 'monitor'
  | 'helper'
  | 'updates'
  | 'menubar'
  | 'onboard'
  | 'settings'

type FeatureSection = {
  id: string
  title: string
  lede: string
  points: string[]
  categories?: string[]
  motif: Motif
  stageLabel: string
  stageHint: string
}

const featureSections: FeatureSection[] = [
  {
    id: 'smart-care',
    title: 'Smart Care',
    lede: 'Multi-category reclaimable-space scan — you stay in control.',
    motif: 'scan',
    stageLabel: 'Scan overview',
    stageHint: 'Select · review · Trash',
    points: [
      'Run Smart Care with per-category progress',
      'Metrics for reclaimable space, scanned size, and status',
      'Click a module to open category detail',
      'Clean selected items into the macOS Trash',
      'Exclude paths you want to keep forever',
      'Large & old files stay unselected until you review them',
      'Stop during scan or cleanup — scan keeps running if you change sections',
    ],
    categories: [
      'User caches & logs',
      'Trash',
      'Xcode DerivedData & Archives',
      'Developer caches (npm, Homebrew, pip, Gradle, Yarn, pnpm, Cargo…)',
      'AI app data (Ollama, LM Studio — never auto-selected)',
      'Old downloads & disk images',
      'Browser caches (Safari, Chrome, Firefox, Edge)',
      'Mail Downloads & MailData',
      'Large & old files (>100 MB or older than 1 year — never auto-selected)',
      'App leftovers & invalid Launch Agents',
      'System caches / logs / agents (admin + allowlist)',
    ],
  },
  {
    id: 'applications',
    title: 'Applications',
    lede: 'Mindful uninstall with related leftovers — nothing removed by surprise.',
    motif: 'apps',
    stageLabel: 'Uninstall review',
    stageHint: 'App + leftovers',
    points: [
      'Browse user apps; search by name or bundle ID',
      'Strict / Enhanced / Deep leftover matching (Team ID, vendor prefixes, Spotlight)',
      'Drag a .app onto the window to review leftovers',
      'Leftovers across Preferences, Caches, Application Support, Containers, Group Containers, Launch Agents, and more',
      'Toggle whether to include the app bundle itself',
      'Finder recycle for /Applications, with admin fallback when needed',
      'Finder → Services → Uninstall with MacCleaner',
      'System apps stay protected — uninstall disabled',
    ],
  },
  {
    id: 'orphans',
    title: 'Orphan Finder',
    lede: 'Leftovers whose apps are already gone — review, select, Trash.',
    motif: 'orphans',
    stageLabel: 'Orphan list',
    stageHint: 'No matching app',
    points: [
      'Match Library debris against currently installed bundle IDs',
      'See path, kind, and size before acting',
      'Select all or cherry-pick; move to Trash only what you choose',
      'Reveal any leftover in Finder',
    ],
  },
  {
    id: 'duplicates',
    title: 'Duplicate Finder',
    lede: 'Exact copies only — size + SHA-256, with one protected file per group.',
    motif: 'dupes',
    stageLabel: 'Duplicate groups',
    stageHint: 'One kept · rest optional',
    points: [
      'Choose any folder to scan',
      'Hard links collapse to a single logical file',
      'Packages, symlinks, and hidden items are skipped',
      'Keep a protected original; move selected extras to Trash',
      'Reveal any path in Finder before you act',
    ],
  },
  {
    id: 'similar-photos',
    title: 'Similar Photos',
    lede: 'Visual estimate from local thumbnails — review only, never delete or upload.',
    motif: 'photos',
    stageLabel: 'Photo groups',
    stageHint: 'Local thumbs only',
    points: [
      'Compare camera rolls and export folders on disk',
      'Groups likely matches for side-by-side review',
      'Reveal originals in Finder at full quality',
      'Limits: 500 photos / 10,000 directory entries per scan',
      'Cloud-only placeholders and app packages are skipped',
    ],
  },
  {
    id: 'startup',
    title: 'Startup',
    lede: 'Launch Agents and local snapshots that quietly eat disk or boot time.',
    motif: 'startup',
    stageLabel: 'Agents & snapshots',
    stageHint: 'User domain',
    points: [
      'List user Launch Agents; flag broken ones',
      'Remove selected agents from the user domain only',
      'Browse local Time Machine / APFS snapshots',
      'Thin selected snapshots with an admin prompt when needed',
    ],
  },
  {
    id: 'developer',
    title: 'Developer Cleanup',
    lede: 'Toolchain caches, Simulator runtimes, Docker, and local AI models.',
    motif: 'dev',
    stageLabel: 'Dev targets',
    stageHint: 'Trash or permanent',
    points: [
      'Xcode DerivedData, Archives, Device Support, Core Simulator',
      'Simulator runtimes via simctl (permanent, opt-in)',
      'Docker data folders plus optional builder prune when Docker is running',
      'Ollama / LM Studio and package-manager caches',
      'Folder targets go to Trash; simctl/Docker prune are labeled permanent',
    ],
  },
  {
    id: 'space-explorer',
    title: 'Space Explorer',
    lede: 'Drill into any folder and see what actually takes space.',
    motif: 'space',
    stageLabel: 'Folder map',
    stageHint: 'Measure only',
    points: [
      'Open Home, Applications, or pick any directory',
      'Children ranked by size with breadcrumbs',
      'Reveal paths in Finder; navigate up or deeper',
      'Measure-only — no silent deletes from this view',
    ],
  },
  {
    id: 'privacy',
    title: 'Privacy',
    lede: 'See purgeable space and permission inventory — change nothing silently.',
    motif: 'privacy',
    stageLabel: 'Privacy hub',
    stageHint: 'Read-only inventory',
    points: [
      'APFS purgeable estimate with optional snapshot thinning',
      'Read-only TCC inventory for your user domain',
      'Full Disk Access status',
      'Deep links into System Settings and browser privacy panes',
    ],
  },
  {
    id: 'history',
    title: 'Cleanup History',
    lede: 'Local log of what you freed — share a card, never upload a path.',
    motif: 'space',
    stageLabel: 'Freed over time',
    stageHint: 'Local only',
    points: [
      'Lifetime and 30-day totals across Smart Care, uninstall, orphans, and more',
      'Animated 14-day chart of space freed',
      'Share or copy a session card — image and text stay on your Mac',
      'Clear or delete entries anytime; nothing is sent to a server',
    ],
  },
  {
    id: 'schedule',
    title: 'Schedule',
    lede: 'Background Smart Care while MacCleaner stays in the menu bar.',
    motif: 'schedule',
    stageLabel: 'Care cadence',
    stageHint: 'Hourly → monthly',
    points: [
      'Intervals from every hour to monthly',
      'Optional auto-clean when reclaimable space meets a MB threshold',
      'Run a cycle immediately from the Schedule screen',
      'Works best with Full Disk Access and the menu bar icon enabled',
    ],
  },
  {
    id: 'performance',
    title: 'System Monitor',
    lede: 'Live CPU, memory, and apps — with search, sort, and helper grouping.',
    motif: 'monitor',
    stageLabel: 'Live meters',
    stageHint: 'CPU · Memory · Apps',
    points: [
      'Host CPU/memory/disk/uptime with delta-based CPU sampling',
      'Apps and processes with icons, live CPU%, memory, search, and sort',
      'Helpers grouped under their parent app; show-all toggle for fuller lists',
      'System processes left to Activity Monitor; jump there in one click',
      'Maintenance: DNS flush (admin), Mail VACUUM, APFS snapshot thinning (admin), Launch Services rebuild',
      'Menu bar glass panel keeps live meters while the app stays resident',
    ],
  },
  {
    id: 'privileged',
    title: 'Privileged helper',
    lede: 'Elevated work only through a password prompt and an explicit path allowlist.',
    motif: 'helper',
    stageLabel: 'Admin bridge',
    stageHint: 'Allowlisted paths',
    points: [
      'Admin bridge for system caches, logs, and agents',
      'DNS flush and APFS snapshot thinning',
      'Only allowlisted paths — never arbitrary shell',
      'Roadmap: signed SMAppService daemon (see docs)',
    ],
  },
  {
    id: 'app-updates',
    title: 'App Updates',
    lede: 'Upgrade Homebrew cask apps you already manage with brew.',
    motif: 'updates',
    stageLabel: 'Cask updates',
    stageHint: 'Homebrew · App Store',
    points: [
      'Lists outdated casks from your local Homebrew install',
      'Select which apps to upgrade; stop between packages',
      'Shows installed → available versions and missing app bundles',
      'Shortcut to Mac App Store updates for non-Homebrew apps',
    ],
  },
  {
    id: 'updates',
    title: 'Updates',
    lede: 'MacCleaner releases from GitHub, with a Homebrew summary.',
    motif: 'updates',
    stageLabel: 'Release check',
    stageHint: 'GitHub · brew',
    points: [
      'Compare local version with releases/version.json',
      'Download from GitHub Releases and install to ~/Applications',
      'Compact Homebrew cask summary linking to App Updates',
      'Network only to GitHub (and local brew), and only when you ask',
    ],
  },
  {
    id: 'menubar',
    title: 'Menu bar',
    lede: 'One-click glass status panel next to the clock.',
    motif: 'menubar',
    stageLabel: 'Status panel',
    stageHint: 'Always nearby',
    points: [
      'Live tiles for disk, memory, battery, CPU, network, and activity',
      'Smart Care tip and quick actions',
      'Closing the main window keeps the app in the menu bar',
      'Open main window or Settings from the panel',
      'Single app instance — no duplicate windows',
    ],
  },
  {
    id: 'onboarding',
    title: 'Onboarding & permissions',
    lede: 'First launch asks for Full Disk Access so protected Library paths can be scanned.',
    motif: 'onboard',
    stageLabel: 'FDA guide',
    stageHint: 'System Settings link',
    points: [
      'Guided Full Disk Access slide with System Settings deep link',
      'Recheck while you grant access; continue when ready',
      'Banner on Smart Care if FDA is still off',
      'Read-only FileVault / Gatekeeper status in Settings',
    ],
  },
  {
    id: 'settings',
    title: 'Settings',
    lede: 'Language, exclusions, and how MacCleaner stays out of the way.',
    motif: 'settings',
    stageLabel: 'Preferences',
    stageHint: '10 languages',
    points: [
      'Languages: System, English, Italian, German, French, Spanish, Portuguese (Brazil), Japanese, Simplified Chinese, Greek, Russian',
      'Cleanup exclusion list for protected paths',
      'Show menu bar icon / hide Dock icon',
      'Launch at login',
      'Install or remove from ~/Applications',
      'Full quit only from Settings → Quit',
    ],
  },
]

const vignetteBars: Record<string, { label: string; width: string; size: string }[]> = {
  scan: [
    { label: 'Caches', width: '78%', size: '4.2 GB' },
    { label: 'Xcode', width: '62%', size: '2.8 GB' },
    { label: 'Browsers', width: '44%', size: '1.1 GB' },
    { label: 'Large & old', width: '91%', size: '6.4 GB' },
  ],
  space: [
    { label: 'Library', width: '86%', size: '48 GB' },
    { label: 'Documents', width: '58%', size: '22 GB' },
    { label: 'Downloads', width: '41%', size: '9.4 GB' },
    { label: 'Movies', width: '33%', size: '7.1 GB' },
  ],
}

const vignetteApps = [
  { name: 'Sketch', leftovers: '12 files' },
  { name: 'Slack', leftovers: '8 files' },
  { name: 'Figma', leftovers: '5 files' },
]

const vignetteOrphans = [
  { path: '~/Library/Caches/com.old…', size: '812 MB' },
  { path: '~/Library/Application Support/…', size: '240 MB' },
  { path: '~/Library/Preferences/…', size: '48 KB' },
]

const vignetteDev = ['DerivedData', 'simctl', 'Docker', 'Ollama', 'npm', 'Cargo']

const vignetteMeters = [
  { label: 'CPU', value: '28%' },
  { label: 'Memory', value: '14.2 GB' },
  { label: 'Disk', value: '62%' },
]

const vignetteProcesses = [
  { name: 'Safari', cpu: '12%', mem: '1.1 GB' },
  { name: 'Xcode', cpu: '8%', mem: '2.4 GB' },
  { name: 'Docker', cpu: '4%', mem: '890 MB' },
]
</script>

<template>
  <div class="page">
    <header class="top">
      <a class="brand" href="#" aria-label="MacCleaner home">
        <img src="/icon.png" alt="" width="36" height="36" class="brand-icon" />
        <span>MacCleaner</span>
      </a>
      <nav class="nav" aria-label="Primary">
        <a href="#privacy">Privacy</a>
        <a href="#features">Features</a>
        <a href="#install">Install</a>
        <a href="#cli">CLI</a>
        <a href="#roadmap">Roadmap</a>
        <a class="nav-ghost" :href="repoUrl" target="_blank" rel="noreferrer">GitHub</a>
      </nav>
    </header>

    <main>
      <section class="hero" aria-labelledby="hero-title">
        <div class="hero-copy">
          <p class="eyebrow">Open source · macOS 14+</p>
          <h1 id="hero-title" class="brand-hero">MacCleaner</h1>
          <p class="lede">
            Reclaim space, uninstall apps with leftovers, explore disk use,
            clean developer and AI toolchains, monitor CPU and memory, and
            schedule Smart Care — with visible paths and full control. Zero
            telemetry. Zero accounts. Zero cloud.
          </p>
          <div class="cta-row">
            <a class="btn btn-primary" :href="dmgUrl">Download MacCleaner {{ version }}</a>
            <a class="btn btn-ghost" :href="repoUrl" target="_blank" rel="noreferrer">
              Source code
            </a>
          </div>
          <div class="hero-brew">
            <span class="hero-brew-or">or</span>
            <button
              type="button"
              class="brew-chip"
              :class="{ copied: brewCopied }"
              :aria-label="brewCopied ? 'Copied Homebrew install commands' : 'Copy Homebrew install commands'"
              @click="copyBrewCommands('hero')"
            >
              <code>{{ brewDisplay }}</code>
              <span class="brew-chip-action" aria-hidden="true">
                <svg v-if="!brewCopied" class="brew-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="9" y="9" width="13" height="13" rx="2" />
                  <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                </svg>
                <svg v-else class="brew-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M20 6 9 17l-5-5" />
                </svg>
              </span>
            </button>
            <button
              type="button"
              class="brew-chip"
              :class="{ copied: cliHeroCopied }"
              :aria-label="cliHeroCopied ? 'Copied CLI install commands' : 'Copy CLI install commands'"
              @click="copyCliHero"
            >
              <code>{{ cliBrewDisplay }}</code>
              <span class="brew-chip-action" aria-hidden="true">
                <svg v-if="!cliHeroCopied" class="brew-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <rect x="9" y="9" width="13" height="13" rx="2" />
                  <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                </svg>
                <svg v-else class="brew-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M20 6 9 17l-5-5" />
                </svg>
              </span>
            </button>
          </div>
          <p class="fine">
            Universal Apple silicon + Intel · 10 languages · MIT · DMG {{ version }} ·
            <a href="#cli">CLI docs</a>
          </p>
        </div>
        <div class="hero-visual" aria-hidden="true">
          <div class="glow" />
          <img src="/banner.svg" alt="" class="hero-banner" width="960" height="640" />
        </div>
      </section>

      <section id="privacy" class="section" aria-labelledby="privacy-title">
        <div class="section-head">
          <h2 id="privacy-title">Verifiable trust</h2>
          <p>A cleaner deserves transparency, not slogans. This is the contract.</p>
        </div>
        <div class="cards">
          <article v-for="item in promises" :key="item.title" class="card">
            <h3>{{ item.title }}</h3>
            <p>{{ item.body }}</p>
          </article>
        </div>
      </section>

      <section id="features" class="section features-section" aria-labelledby="features-title">
        <div class="section-head">
          <h2 id="features-title">Features</h2>
          <p>
            Smart Care, deep uninstall, orphan finder, Space Explorer, startup
            tools, privacy hub, duplicates, similar photos, System Monitor,
            Developer Cleanup, scheduling, and more — every tool is local,
            selective, and path-visible.
          </p>
        </div>
        <div class="shipped-strip" aria-label="Recently shipped">
          <p class="shipped-label">Recently shipped</p>
          <ul>
            <li v-for="item in recentlyShipped" :key="item">{{ item }}</li>
          </ul>
        </div>

        <nav class="feature-jump" aria-label="Feature sections">
          <a
            v-for="section in featureSections"
            :key="section.id"
            :href="`#${section.id}`"
          >
            {{ section.title }}
          </a>
        </nav>

        <div class="feature-rail">
          <article
            v-for="(section, index) in featureSections"
            :id="section.id"
            :key="section.id"
            class="feature-scene"
            :class="{ flip: index % 2 === 1 }"
            :aria-labelledby="`${section.id}-title`"
          >
            <div class="feature-copy">
              <h3 :id="`${section.id}-title`">{{ section.title }}</h3>
              <p class="feature-lede">{{ section.lede }}</p>
              <ul class="point-list">
                <li v-for="point in section.points" :key="point">{{ point }}</li>
              </ul>
              <div v-if="section.categories" class="cat-wrap">
                <p class="cat-label">Scan categories</p>
                <ul class="cat-list">
                  <li v-for="cat in section.categories" :key="cat">{{ cat }}</li>
                </ul>
              </div>
            </div>

            <div class="feature-stage" aria-hidden="true">
              <div class="stage-frame" :data-motif="section.motif">
                <div class="stage-chrome">
                  <span class="stage-dots" />
                  <span class="stage-title">{{ section.stageLabel }}</span>
                  <span class="stage-hint">{{ section.stageHint }}</span>
                </div>

                <div v-if="section.motif === 'scan'" class="vignette vignette-scan">
                  <div class="v-metric">
                    <span>Reclaimable</span>
                    <strong>14.5 GB</strong>
                  </div>
                  <div
                    v-for="bar in vignetteBars.scan"
                    :key="bar.label"
                    class="v-bar-row"
                  >
                    <div class="v-bar-meta">
                      <span>{{ bar.label }}</span>
                      <span>{{ bar.size }}</span>
                    </div>
                    <div class="v-bar-track">
                      <i :style="{ width: bar.width }" />
                    </div>
                  </div>
                </div>

                <div v-else-if="section.motif === 'apps'" class="vignette vignette-apps">
                  <div
                    v-for="app in vignetteApps"
                    :key="app.name"
                    class="v-app-row"
                  >
                    <span class="v-app-icon" />
                    <div>
                      <strong>{{ app.name }}</strong>
                      <span>{{ app.leftovers }}</span>
                    </div>
                    <em>Review</em>
                  </div>
                </div>

                <div v-else-if="section.motif === 'orphans'" class="vignette vignette-list">
                  <div
                    v-for="row in vignetteOrphans"
                    :key="row.path"
                    class="v-list-row"
                  >
                    <span class="v-check" />
                    <code>{{ row.path }}</code>
                    <span>{{ row.size }}</span>
                  </div>
                </div>

                <div v-else-if="section.motif === 'dupes'" class="vignette vignette-dupes">
                  <div class="v-dupe-group">
                    <span class="v-keep">Protected</span>
                    <code>Report-final.pdf</code>
                    <span>4.2 MB</span>
                  </div>
                  <div class="v-dupe-group muted">
                    <span class="v-extra">Extra</span>
                    <code>Report-final (1).pdf</code>
                    <span>4.2 MB</span>
                  </div>
                  <div class="v-dupe-group muted">
                    <span class="v-extra">Extra</span>
                    <code>Report-final copy.pdf</code>
                    <span>4.2 MB</span>
                  </div>
                </div>

                <div v-else-if="section.motif === 'photos'" class="vignette vignette-photos">
                  <div class="v-photo" /><div class="v-photo" /><div class="v-photo" />
                  <div class="v-photo" /><div class="v-photo" /><div class="v-photo" />
                </div>

                <div v-else-if="section.motif === 'startup'" class="vignette vignette-startup">
                  <div class="v-agent">
                    <strong>com.vendor.updater</strong>
                    <span class="badge bad">Broken</span>
                  </div>
                  <div class="v-agent">
                    <strong>com.tools.helper</strong>
                    <span class="badge ok">Loaded</span>
                  </div>
                  <div class="v-snap">
                    <span>Local snapshots</span>
                    <strong>3 · 18.4 GB</strong>
                  </div>
                </div>

                <div v-else-if="section.motif === 'dev'" class="vignette vignette-chips">
                  <span v-for="chip in vignetteDev" :key="chip" class="v-chip">{{ chip }}</span>
                </div>

                <div v-else-if="section.motif === 'space'" class="vignette vignette-scan">
                  <div class="v-crumb">~/Library → Caches</div>
                  <div
                    v-for="bar in vignetteBars.space"
                    :key="bar.label"
                    class="v-bar-row"
                  >
                    <div class="v-bar-meta">
                      <span>{{ bar.label }}</span>
                      <span>{{ bar.size }}</span>
                    </div>
                    <div class="v-bar-track">
                      <i :style="{ width: bar.width }" />
                    </div>
                  </div>
                </div>

                <div v-else-if="section.motif === 'privacy'" class="vignette vignette-privacy">
                  <div class="v-pill">Purgeable · ~6.2 GB</div>
                  <div class="v-tcc">
                    <span>Full Disk Access</span>
                    <em class="on">On</em>
                  </div>
                  <div class="v-tcc">
                    <span>Camera</span>
                    <em>Denied</em>
                  </div>
                  <div class="v-tcc">
                    <span>Contacts</span>
                    <em>Not determined</em>
                  </div>
                </div>

                <div v-else-if="section.motif === 'schedule'" class="vignette vignette-schedule">
                  <div class="v-clock">
                    <strong>Every day</strong>
                    <span>Next · 09:00</span>
                  </div>
                  <div class="v-threshold">
                    <span>Auto-clean when</span>
                    <strong>≥ 500 MB</strong>
                  </div>
                  <button type="button" tabindex="-1" class="v-run">Run cycle now</button>
                </div>

                <div v-else-if="section.motif === 'monitor'" class="vignette vignette-monitor">
                  <div class="v-meters">
                    <div v-for="m in vignetteMeters" :key="m.label" class="v-meter">
                      <span>{{ m.label }}</span>
                      <strong>{{ m.value }}</strong>
                    </div>
                  </div>
                  <div
                    v-for="proc in vignetteProcesses"
                    :key="proc.name"
                    class="v-proc"
                  >
                    <span class="v-app-icon sm" />
                    <strong>{{ proc.name }}</strong>
                    <span>{{ proc.cpu }}</span>
                    <span>{{ proc.mem }}</span>
                  </div>
                </div>

                <div v-else-if="section.motif === 'helper'" class="vignette vignette-helper">
                  <div class="v-shield">Admin prompt</div>
                  <code>/Library/Caches/…</code>
                  <code>/private/var/log/…</code>
                  <span class="v-allow">Allowlisted only</span>
                </div>

                <div v-else-if="section.motif === 'updates'" class="vignette vignette-updates">
                  <div class="v-ver">
                    <span>Installed</span>
                    <strong>{{ version }}</strong>
                  </div>
                  <div class="v-ver latest">
                    <span>Latest</span>
                    <strong>{{ version }}</strong>
                  </div>
                  <div class="v-cask">Homebrew casks · 3 outdated</div>
                </div>

                <div v-else-if="section.motif === 'menubar'" class="vignette vignette-menubar">
                  <div class="v-tile" v-for="t in ['Disk', 'Mem', 'CPU', 'Net']" :key="t">
                    <span>{{ t }}</span>
                    <i />
                  </div>
                </div>

                <div v-else-if="section.motif === 'onboard'" class="vignette vignette-onboard">
                  <strong>Full Disk Access</strong>
                  <p>Grant access so protected Library paths can be scanned.</p>
                  <span class="v-link">Open System Settings</span>
                </div>

                <div v-else class="vignette vignette-settings">
                  <div class="v-setting">
                    <span>Language</span>
                    <em>System</em>
                  </div>
                  <div class="v-setting">
                    <span>Menu bar icon</span>
                    <em class="on">On</em>
                  </div>
                  <div class="v-setting">
                    <span>Launch at login</span>
                    <em class="on">On</em>
                  </div>
                  <div class="v-setting">
                    <span>Exclusions</span>
                    <em>4 paths</em>
                  </div>
                </div>
              </div>
            </div>
          </article>
        </div>
      </section>

      <section id="install" class="section install" aria-labelledby="install-title">
        <div class="section-head">
          <h2 id="install-title">Install</h2>
          <p>
            One universal build for Apple silicon and Intel — DMG, zip, or
            Homebrew. Version {{ version }}, Developer ID signed and notarized.
          </p>
        </div>

        <ol class="install-path">
          <li class="install-step">
            <span class="install-step-mark" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
                <path d="M12 3v12" />
                <path d="m7 10 5 5 5-5" />
                <path d="M5 19h14" />
              </svg>
            </span>
            <div class="install-step-copy">
              <strong>Download</strong>
              <p>
                <a :href="dmgUrl">MacCleaner-{{ version }}.dmg</a>
                <span class="install-badge">Notarized</span>
              </p>
            </div>
          </li>
          <li class="install-step">
            <span class="install-step-mark" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
                <rect x="3" y="4" width="8" height="10" rx="1.5" />
                <path d="M14 9h4.5a2.5 2.5 0 0 1 0 5H14" />
                <path d="m16 11 3 3-3 3" />
              </svg>
            </span>
            <div class="install-step-copy">
              <strong>Drag into Applications</strong>
              <p>Open the disk image and drop MacCleaner.app into Applications.</p>
            </div>
          </li>
          <li class="install-step">
            <span class="install-step-mark" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">
                <circle cx="12" cy="12" r="9" />
                <path d="M10 9.5v5l5-2.5-5-2.5z" fill="currentColor" stroke="none" />
              </svg>
            </span>
            <div class="install-step-copy">
              <strong>Open</strong>
              <p>Launch from Applications — Gatekeeper accepts notarized builds.</p>
            </div>
          </li>
        </ol>

        <div class="install-stage" aria-hidden="true">
          <div class="install-stage-orb">
            <span class="install-app-tile">
              <img src="/icon.png" alt="" width="28" height="28" />
              MacCleaner.app
            </span>
          </div>
          <svg class="install-stage-arrow" viewBox="0 0 80 24" width="80" height="24" fill="none">
            <path d="M4 12h64" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
            <path d="M58 5l14 7-14 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
          <div class="install-stage-orb apps">
            <span class="install-apps-tile">
              <svg viewBox="0 0 32 28" width="36" height="32" aria-hidden="true">
                <path d="M4 8h24v16a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8z" fill="#4da3ff" />
                <path d="M2 8h12l3-4h13a2 2 0 0 1 2 2v2H2z" fill="#7ec0ff" />
              </svg>
              Applications
            </span>
          </div>
        </div>

        <div class="cta-row install-ctas">
          <a class="btn btn-primary" :href="dmgUrl">Download MacCleaner {{ version }}</a>
          <a class="btn btn-ghost" :href="zipUrl">Download zip</a>
          <a class="btn btn-ghost" :href="`${repoUrl}/releases`" target="_blank" rel="noreferrer">
            All releases
          </a>
        </div>

        <div class="brew-box">
          <div class="brew-box-head">
            <h3>Homebrew (app)</h3>
            <button
              type="button"
              class="brew-copy-btn"
              :class="{ copied: brewCopiedInstall }"
              :aria-label="brewCopiedInstall ? 'Copied' : 'Copy Homebrew commands'"
              @click="copyBrewCommands('install')"
            >
              {{ brewCopiedInstall ? 'Copied' : 'Copy' }}
            </button>
          </div>
          <p>GUI app via cask — same {{ version }} build as the DMG:</p>
          <pre><code>{{ brewCommands }}</code></pre>
          <p class="cli-note">
            Want the terminal tool instead? See
            <a href="#cli">Command line</a> —
            <code>./Scripts/install-cli.sh</code> (or the Homebrew formula).
          </p>
        </div>
      </section>

      <section id="cli" class="section cli" aria-labelledby="cli-title">
        <div class="section-head">
          <h2 id="cli-title">Command line</h2>
          <p>
            Install <code>maccleaner</code> on its own — separate from the GUI
            cask. Interactive TUI on a real terminal, or scriptable flags.
            Same engines as the app. Zero telemetry.
          </p>
        </div>

        <div class="cli-grid">
          <div class="brew-box">
            <div class="brew-box-head">
              <h3>From a clone (recommended)</h3>
              <button
                type="button"
                class="brew-copy-btn"
                :class="{ copied: cliInstallCopied }"
                :aria-label="cliInstallCopied ? 'Copied' : 'Copy CLI install commands'"
                @click="copyCliInstall"
              >
                {{ cliInstallCopied ? 'Copied' : 'Copy' }}
              </button>
            </div>
            <p>
              Builds with your Xcode <code>swift</code> toolchain and installs
              to <code>$(brew --prefix)/bin/maccleaner</code> — works even when
              Homebrew refuses to compile:
            </p>
            <pre><code>{{ cliInstallCommands }}</code></pre>
            <p class="cli-note">
              Maintainers: <code>./Scripts/package-cli.sh</code> writes
              <code>releases/maccleaner-cli-*.tar.gz</code> for a future
              <code>cli-v*</code> GitHub release (prebuilt = no compile).
            </p>
          </div>

          <div class="brew-box">
            <div class="brew-box-head">
              <h3>Homebrew (CLI)</h3>
              <button
                type="button"
                class="brew-copy-btn"
                :class="{ copied: cliCloneCopied }"
                :aria-label="cliCloneCopied ? 'Copied' : 'Copy brew CLI install commands'"
                @click="copyCliClone"
              >
                {{ cliCloneCopied ? 'Copied' : 'Copy' }}
              </button>
            </div>
            <p>
              Formula <code>maccleaner-cli</code> — does not install
              MacCleaner.app. <code>--HEAD</code> builds from source until a
              <code>cli-v*</code> asset exists:
            </p>
            <pre><code>{{ cliBrewAltCommands }}</code></pre>
            <p class="cli-note">
              If brew says <em>CLT does not support macOS …</em>, update
              Command Line Tools (Software Update) or use
              <code>./Scripts/install-cli.sh</code>. Upgrade / remove:
            </p>
            <pre><code>{{ cliUpgradeCommands }}</code></pre>
          </div>
        </div>

        <div class="brew-box cli-usage-box">
          <div class="brew-box-head">
            <h3>Usage</h3>
            <button
              type="button"
              class="brew-copy-btn"
              :class="{ copied: cliUsageCopied }"
              :aria-label="cliUsageCopied ? 'Copied' : 'Copy CLI usage commands'"
              @click="copyCliUsage"
            >
              {{ cliUsageCopied ? 'Copied' : 'Copy' }}
            </button>
          </div>
          <p>Workspace, cleanup, and scripts:</p>
          <pre><code>{{ cliUsageCommands }}</code></pre>
        </div>

        <div class="cli-keys">
          <h3>TUI keys</h3>
          <ul>
            <li><kbd>↑</kbd><kbd>↓</kbd> Move</li>
            <li><kbd>Space</kbd> Toggle item</li>
            <li><kbd>A</kbd> / <kbd>N</kbd> Select matching / clear</li>
            <li><kbd>/</kbd> Search</li>
            <li><kbd>Enter</kbd> Review / continue</li>
            <li><kbd>Esc</kbd> / <kbd>Q</kbd> Cancel</li>
          </ul>
          <p>
            Interactive cleanup asks you to type <strong>yes</strong> before
            anything goes to the Trash. Use
            <code>--include-privileged</code> only when you want system
            allowlisted paths. After a <code>cli-v*</code> release,
            <code>brew install maccleaner-cli</code> (without
            <code>--HEAD</code>) will install the prebuilt binary.
          </p>
        </div>
      </section>

      <section id="roadmap" class="section roadmap" aria-labelledby="roadmap-title">
        <div class="section-head">
          <h2 id="roadmap-title">Roadmap</h2>
          <p>
            Next updates in roughly this order — privileged helper and CLI
            packaging, then the high-value list we are tracking.
          </p>
        </div>
        <ol class="roadmap-list">
          <li v-for="(item, index) in roadmapNext" :key="item.title">
            <span class="roadmap-index">{{ index + 1 }}</span>
            <div>
              <strong>{{ item.title }}</strong>
              <p>{{ item.body }}</p>
            </div>
          </li>
        </ol>
        <div class="roadmap-later">
          <h3>Later / niche</h3>
          <ul>
            <li v-for="item in roadmapLater" :key="item">{{ item }}</li>
          </ul>
          <p class="roadmap-avoid">
            Out of scope: RAM boosters, treating purgeable space as junk, and
            fake malware / FUD claims.
          </p>
        </div>
      </section>
    </main>

    <footer class="footer">
      <div>
        <strong>MacCleaner</strong>
        <span>MIT · 100% local privacy · v{{ version }}</span>
      </div>
      <a :href="repoUrl" target="_blank" rel="noreferrer">github.com/mponzo/MacCleaner</a>
    </footer>
  </div>
</template>

<style scoped>
.page {
  width: min(1180px, calc(100% - 2.5rem));
  margin: 0 auto;
  padding: 1.25rem 0 3rem;
}

.top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 2.5rem;
  animation: rise 0.7s ease both;
}

.brand {
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
  font-family: var(--font-display);
  font-weight: 700;
  font-size: 1.05rem;
  letter-spacing: -0.02em;
}

.brand-icon {
  border-radius: 9px;
  box-shadow: 0 6px 18px var(--shadow);
}

.nav {
  display: flex;
  flex-wrap: wrap;
  gap: 0.85rem 1.15rem;
  align-items: center;
  color: var(--muted);
  font-size: 0.95rem;
  font-weight: 500;
}

.nav a:hover {
  color: var(--ink);
}

.nav a:focus-visible,
.feature-jump a:focus-visible,
.btn:focus-visible {
  outline: 2px solid var(--sea);
  outline-offset: 3px;
}

.nav-ghost {
  padding: 0.4rem 0.8rem;
  border: 1px solid var(--stroke);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.04);
}

.hero {
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(0, 0.95fr);
  gap: 2rem;
  align-items: center;
  min-height: min(72vh, 640px);
  margin-bottom: 4.5rem;
}

.hero-copy {
  min-width: 0;
  max-width: 100%;
  container-type: inline-size;
  animation: rise 0.85s 0.08s ease both;
}

.eyebrow {
  margin: 0 0 0.85rem;
  color: var(--sea);
  font-size: 0.85rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.brand-hero {
  margin: 0;
  max-width: 100%;
  font-family: var(--font-display);
  font-size: clamp(1.5rem, 9vw, 5.4rem);
  font-size: clamp(1.5rem, 10cqi, 5.4rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 0.95;
  white-space: nowrap;
}

.lede {
  margin: 1.1rem 0 0;
  max-width: 34ch;
  color: var(--muted);
  font-size: clamp(1.05rem, 2vw, 1.25rem);
  line-height: 1.55;
}

.cta-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-top: 1.6rem;
}

.hero-brew {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.65rem;
  margin-top: 1.15rem;
}

.hero-brew-or {
  color: var(--faint);
  font-size: 0.92rem;
  font-weight: 500;
}

.brew-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
  max-width: 100%;
  margin: 0;
  padding: 0.55rem 0.7rem 0.55rem 0.9rem;
  border: 1px solid var(--stroke);
  border-radius: 12px;
  background: rgba(7, 18, 36, 0.72);
  color: var(--ink);
  cursor: pointer;
  font: inherit;
  transition:
    border-color 0.18s ease,
    background 0.18s ease,
    transform 0.18s ease;
}

.brew-chip:hover {
  border-color: rgba(77, 163, 255, 0.45);
  background: rgba(10, 26, 51, 0.9);
}

.brew-chip:focus-visible {
  outline: 2px solid var(--sea);
  outline-offset: 3px;
}

.brew-chip:active {
  transform: scale(0.985);
}

.brew-chip.copied {
  border-color: rgba(159, 224, 184, 0.45);
}

.brew-chip code {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.88rem;
  color: var(--muted);
}

.brew-chip-action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 1.7rem;
  height: 1.7rem;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.06);
  color: var(--sea);
}

.brew-chip.copied .brew-chip-action {
  color: #9fe0b8;
  background: rgba(80, 200, 120, 0.14);
}

.brew-icon {
  display: block;
}

.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 2.85rem;
  padding: 0.7rem 1.25rem;
  border-radius: 12px;
  font-weight: 650;
  transition: transform 0.18s ease, box-shadow 0.18s ease, background 0.18s ease;
}

.btn:hover {
  transform: translateY(-1px) scale(1.015);
}

.btn:active {
  transform: scale(0.985);
}

.btn-primary {
  color: #fff;
  background: linear-gradient(180deg, #5bb0ff 0%, var(--sea-deep) 100%);
  box-shadow: 0 10px 28px rgba(46, 107, 209, 0.4);
}

.btn-ghost {
  color: var(--ink);
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.05);
}

.fine {
  margin: 0.95rem 0 0;
  color: var(--faint);
  font-size: 0.88rem;
}

.hero-visual {
  position: relative;
  min-width: 0;
  max-width: 100%;
  animation: float-in 1s 0.15s ease both;
}

.glow {
  position: absolute;
  inset: 8% 5%;
  background: radial-gradient(circle, rgba(77, 163, 255, 0.35), transparent 70%);
  filter: blur(18px);
  pointer-events: none;
}

.hero-banner {
  position: relative;
  display: block;
  width: 100%;
  max-width: 100%;
  height: auto;
  object-fit: cover;
  border-radius: 24px;
  border: 1px solid var(--stroke);
  box-shadow: 0 24px 60px var(--shadow);
  background: rgba(255, 255, 255, 0.03);
}

.section {
  margin-bottom: 4.25rem;
}

.section-head {
  margin-bottom: 1.5rem;
  max-width: 42rem;
}

.section-head h2 {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(1.8rem, 3.5vw, 2.4rem);
  letter-spacing: -0.03em;
}

.section-head p {
  margin: 0.55rem 0 0;
  color: var(--muted);
  font-size: 1.05rem;
  line-height: 1.5;
}

.cards {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
}

.card {
  padding: 1.25rem 1.3rem;
  border-radius: 18px;
  border: 1px solid var(--stroke);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.08), rgba(46, 107, 209, 0.12)),
    rgba(10, 26, 51, 0.35);
  box-shadow: 0 10px 30px rgba(3, 10, 24, 0.25);
  backdrop-filter: blur(14px);
}

.card h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.15rem;
  letter-spacing: -0.02em;
}

.card p {
  margin: 0.55rem 0 0;
  color: var(--muted);
  line-height: 1.5;
  font-size: 0.98rem;
}

.feature-jump {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem 0.65rem;
  margin-bottom: 2.25rem;
  position: sticky;
  top: 0.65rem;
  z-index: 5;
  padding: 0.65rem 0.75rem;
  border-radius: 16px;
  border: 1px solid var(--stroke);
  background: rgba(7, 18, 36, 0.82);
  backdrop-filter: blur(16px);
  box-shadow: 0 12px 32px rgba(3, 10, 24, 0.35);
}

.feature-jump a {
  padding: 0.4rem 0.75rem;
  border-radius: 999px;
  border: 1px solid transparent;
  color: var(--muted);
  font-size: 0.88rem;
  font-weight: 600;
  transition: color 0.15s ease, border-color 0.15s ease, background 0.15s ease;
}

.feature-jump a:hover {
  color: var(--ink);
  border-color: rgba(77, 163, 255, 0.45);
  background: rgba(77, 163, 255, 0.08);
}

.feature-rail {
  display: grid;
  gap: 2.75rem;
}

.feature-scene {
  display: grid;
  grid-template-columns: minmax(0, 1.05fr) minmax(0, 0.95fr);
  gap: 1.75rem 2.25rem;
  align-items: stretch;
  scroll-margin-top: 5.5rem;
  padding: 1.75rem;
  border-radius: 28px;
  border: 1px solid var(--stroke);
  background:
    radial-gradient(ellipse 70% 80% at 100% 0%, rgba(77, 163, 255, 0.16), transparent 55%),
    linear-gradient(165deg, rgba(255, 255, 255, 0.07), rgba(10, 26, 51, 0.45));
  box-shadow: 0 18px 48px rgba(3, 10, 24, 0.28);
}

.feature-scene.flip {
  grid-template-columns: minmax(0, 0.95fr) minmax(0, 1.05fr);
}

.feature-scene.flip .feature-copy {
  order: 2;
}

.feature-scene.flip .feature-stage {
  order: 1;
}

.feature-scene.flip {
  background:
    radial-gradient(ellipse 70% 80% at 0% 0%, rgba(77, 163, 255, 0.16), transparent 55%),
    linear-gradient(195deg, rgba(255, 255, 255, 0.07), rgba(10, 26, 51, 0.45));
}

.feature-copy h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(1.65rem, 3vw, 2.15rem);
  letter-spacing: -0.03em;
  line-height: 1.1;
}

.feature-lede {
  margin: 0.65rem 0 0;
  color: var(--muted);
  font-size: 1.08rem;
  line-height: 1.5;
  max-width: 42ch;
}

.point-list,
.cat-list {
  margin: 1.15rem 0 0;
  padding-left: 1.15rem;
  color: var(--muted);
  line-height: 1.55;
}

.point-list li + li,
.cat-list li + li {
  margin-top: 0.4rem;
}

.cat-wrap {
  margin-top: 1.25rem;
  padding-top: 1.1rem;
  border-top: 1px solid var(--stroke);
}

.cat-label {
  margin: 0;
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--sea);
}

.cat-list {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.25rem 1rem;
  margin-top: 0.65rem;
}

.feature-stage {
  min-width: 0;
  display: flex;
}

.stage-frame {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 280px;
  border-radius: 20px;
  border: 1px solid var(--stroke);
  background:
    linear-gradient(180deg, rgba(22, 58, 107, 0.55), rgba(7, 18, 36, 0.92));
  box-shadow:
    inset 0 1px 0 rgba(255, 255, 255, 0.08),
    0 16px 40px rgba(3, 10, 24, 0.35);
  overflow: hidden;
}

.stage-chrome {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.7rem 0.9rem;
  border-bottom: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.03);
}

.stage-dots {
  width: 42px;
  height: 10px;
  border-radius: 999px;
  background:
    radial-gradient(circle at 5px 5px, #ff6b6b 4px, transparent 5px),
    radial-gradient(circle at 21px 5px, #ffd166 4px, transparent 5px),
    radial-gradient(circle at 37px 5px, #6bcb77 4px, transparent 5px);
  opacity: 0.85;
}

.stage-title {
  color: var(--faint);
  font-size: 0.78rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.stage-hint {
  margin-left: auto;
  color: var(--sea);
  font-size: 0.75rem;
  font-weight: 650;
}

.vignette {
  flex: 1;
  padding: 1.1rem 1.15rem 1.25rem;
  display: grid;
  gap: 0.7rem;
  align-content: start;
}

.v-metric {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 0.25rem;
}

.v-metric span {
  color: var(--faint);
  font-size: 0.82rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.v-metric strong {
  font-family: var(--font-display);
  font-size: 1.65rem;
  letter-spacing: -0.03em;
}

.v-bar-row {
  display: grid;
  gap: 0.3rem;
}

.v-bar-meta {
  display: flex;
  justify-content: space-between;
  color: var(--muted);
  font-size: 0.86rem;
}

.v-bar-track {
  height: 8px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.08);
  overflow: hidden;
}

.v-bar-track i {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, #5bb0ff, var(--sea-deep));
}

.v-crumb {
  color: var(--faint);
  font-size: 0.82rem;
  margin-bottom: 0.15rem;
}

.v-app-row,
.v-list-row,
.v-proc,
.v-setting,
.v-tcc,
.v-agent {
  display: flex;
  align-items: center;
  gap: 0.7rem;
  padding: 0.7rem 0.8rem;
  border-radius: 12px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
}

.v-app-icon {
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: linear-gradient(145deg, #5bb0ff, #2e6bd1);
  flex-shrink: 0;
}

.v-app-icon.sm {
  width: 20px;
  height: 20px;
  border-radius: 6px;
}

.v-app-row div {
  display: grid;
  gap: 0.1rem;
  flex: 1;
  min-width: 0;
}

.v-app-row strong,
.v-proc strong,
.v-agent strong {
  font-size: 0.95rem;
}

.v-app-row span,
.v-list-row span,
.v-proc span {
  color: var(--faint);
  font-size: 0.8rem;
}

.v-app-row em {
  color: var(--sea);
  font-style: normal;
  font-size: 0.82rem;
  font-weight: 650;
}

.v-check {
  width: 14px;
  height: 14px;
  border-radius: 4px;
  border: 1.5px solid var(--sea);
  background: rgba(77, 163, 255, 0.25);
  flex-shrink: 0;
}

.v-list-row code,
.v-dupe-group code,
.vignette-helper code {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.78rem;
  color: var(--muted);
}

.v-dupe-group {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 0.55rem;
  align-items: center;
  padding: 0.7rem 0.8rem;
  border-radius: 12px;
  border: 1px solid rgba(77, 163, 255, 0.35);
  background: rgba(77, 163, 255, 0.1);
}

.v-dupe-group.muted {
  border-color: var(--stroke);
  background: rgba(255, 255, 255, 0.03);
  opacity: 0.85;
}

.v-keep,
.v-extra {
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--sea);
}

.v-extra {
  color: var(--accent);
}

.vignette-photos {
  grid-template-columns: repeat(3, 1fr);
  gap: 0.55rem;
}

.v-photo {
  aspect-ratio: 1;
  border-radius: 10px;
  border: 1px solid var(--stroke);
  background:
    linear-gradient(135deg, rgba(77, 163, 255, 0.35), rgba(255, 158, 72, 0.25)),
    rgba(255, 255, 255, 0.05);
}

.v-photo:nth-child(2) {
  background:
    linear-gradient(160deg, rgba(46, 107, 209, 0.5), rgba(10, 26, 51, 0.2)),
    rgba(255, 255, 255, 0.05);
}

.v-photo:nth-child(3n) {
  background:
    linear-gradient(200deg, rgba(255, 158, 72, 0.35), rgba(77, 163, 255, 0.2)),
    rgba(255, 255, 255, 0.05);
}

.badge {
  margin-left: auto;
  padding: 0.2rem 0.5rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
}

.badge.bad {
  color: #ffb4a2;
  background: rgba(255, 110, 80, 0.18);
}

.badge.ok {
  color: #9fe0b8;
  background: rgba(80, 200, 120, 0.16);
}

.v-snap {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  padding: 0.85rem 0.9rem;
  border-radius: 12px;
  border: 1px dashed rgba(77, 163, 255, 0.35);
  color: var(--muted);
}

.v-snap strong {
  color: var(--ink);
  font-family: var(--font-display);
}

.vignette-chips {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.v-chip {
  padding: 0.75rem 0.85rem;
  border-radius: 12px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.05);
  text-align: center;
  font-weight: 650;
  font-size: 0.9rem;
}

.v-pill {
  width: fit-content;
  padding: 0.45rem 0.75rem;
  border-radius: 999px;
  background: rgba(77, 163, 255, 0.16);
  color: var(--sea);
  font-size: 0.82rem;
  font-weight: 700;
}

.v-tcc em,
.v-setting em {
  margin-left: auto;
  font-style: normal;
  color: var(--faint);
  font-size: 0.82rem;
}

.v-tcc em.on,
.v-setting em.on {
  color: #9fe0b8;
}

.vignette-schedule {
  align-content: center;
  gap: 0.9rem;
}

.v-clock,
.v-threshold {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  padding: 1rem 1.05rem;
  border-radius: 14px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
}

.v-clock strong,
.v-threshold strong {
  font-family: var(--font-display);
  font-size: 1.2rem;
}

.v-clock span,
.v-threshold span {
  color: var(--muted);
  font-size: 0.9rem;
}

.v-run {
  appearance: none;
  border: 0;
  border-radius: 12px;
  padding: 0.75rem 1rem;
  color: #fff;
  font: inherit;
  font-weight: 650;
  background: linear-gradient(180deg, #5bb0ff 0%, var(--sea-deep) 100%);
  pointer-events: none;
}

.v-meters {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
  margin-bottom: 0.2rem;
}

.v-meter {
  display: grid;
  gap: 0.2rem;
  padding: 0.65rem 0.7rem;
  border-radius: 12px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
}

.v-meter span {
  color: var(--faint);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.v-meter strong {
  font-family: var(--font-display);
  font-size: 1rem;
}

.v-proc {
  display: grid;
  grid-template-columns: auto 1fr auto auto;
}

.vignette-helper {
  align-content: center;
  text-align: center;
  gap: 0.65rem;
}

.v-shield {
  width: fit-content;
  margin: 0 auto;
  padding: 0.45rem 0.8rem;
  border-radius: 999px;
  background: rgba(255, 158, 72, 0.16);
  color: var(--accent);
  font-size: 0.82rem;
  font-weight: 700;
}

.v-allow {
  color: var(--faint);
  font-size: 0.82rem;
  margin-top: 0.25rem;
}

.v-ver {
  display: flex;
  justify-content: space-between;
  padding: 0.85rem 0.95rem;
  border-radius: 12px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
}

.v-ver.latest {
  border-color: rgba(77, 163, 255, 0.4);
  background: rgba(77, 163, 255, 0.1);
}

.v-ver span {
  color: var(--muted);
}

.v-ver strong {
  font-family: var(--font-display);
}

.v-cask {
  color: var(--faint);
  font-size: 0.88rem;
  text-align: center;
}

.vignette-menubar {
  grid-template-columns: repeat(2, 1fr);
  align-content: center;
}

.v-tile {
  display: grid;
  gap: 0.55rem;
  padding: 0.9rem;
  border-radius: 14px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.05);
}

.v-tile span {
  color: var(--muted);
  font-size: 0.82rem;
  font-weight: 650;
}

.v-tile i {
  display: block;
  height: 6px;
  border-radius: 999px;
  background: linear-gradient(90deg, var(--sea), transparent);
}

.vignette-onboard {
  align-content: center;
  gap: 0.65rem;
  text-align: left;
}

.vignette-onboard strong {
  font-family: var(--font-display);
  font-size: 1.25rem;
}

.vignette-onboard p {
  margin: 0;
  color: var(--muted);
  line-height: 1.45;
}

.v-link {
  color: var(--sea);
  font-weight: 650;
  font-size: 0.92rem;
}

.shipped-strip {
  margin: 0 0 1.75rem;
  padding: 1.15rem 1.25rem;
  border-radius: 18px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
}

.shipped-label {
  margin: 0 0 0.65rem;
  color: var(--sea);
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.shipped-strip ul {
  margin: 0;
  padding-left: 1.15rem;
  color: var(--muted);
  line-height: 1.5;
}

.shipped-strip li + li {
  margin-top: 0.35rem;
}

.roadmap-list {
  list-style: none;
  margin: 0 0 1.75rem;
  padding: 0;
  display: grid;
  gap: 0.75rem;
}

.roadmap-list li {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 0.9rem;
  align-items: start;
  padding: 1rem 1.15rem;
  border-radius: 16px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
}

.roadmap-index {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.85rem;
  height: 1.85rem;
  border-radius: 999px;
  background: rgba(77, 163, 255, 0.16);
  color: var(--sea);
  font-size: 0.85rem;
  font-weight: 700;
}

.roadmap-list strong {
  font-family: var(--font-display);
  font-size: 1.05rem;
  letter-spacing: -0.02em;
}

.roadmap-list p {
  margin: 0.3rem 0 0;
  color: var(--muted);
  line-height: 1.45;
  font-size: 0.95rem;
}

.roadmap-later {
  padding: 1.15rem 1.25rem;
  border-radius: 16px;
  border: 1px dashed rgba(77, 163, 255, 0.35);
  background: rgba(7, 18, 36, 0.35);
}

.roadmap-later h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.05rem;
}

.roadmap-later ul {
  margin: 0.65rem 0 0;
  padding-left: 1.15rem;
  color: var(--muted);
  line-height: 1.5;
}

.roadmap-avoid {
  margin: 0.9rem 0 0;
  color: var(--faint);
  font-size: 0.9rem;
  line-height: 1.45;
}

.install {
  text-align: center;
}

.install .section-head {
  margin-left: auto;
  margin-right: auto;
  max-width: 40rem;
}

.install-path {
  list-style: none;
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  align-items: stretch;
  gap: 1rem;
  width: min(960px, 100%);
  margin: 0 auto 1.75rem;
  padding: 0;
  text-align: left;
}

.install-step {
  position: relative;
  display: flex;
  gap: 0.85rem;
  align-items: flex-start;
  min-width: 0;
  padding: 1.15rem 1.1rem;
  border-radius: 16px;
  border: 1px solid var(--stroke);
  background:
    linear-gradient(165deg, rgba(77, 163, 255, 0.1), transparent 55%),
    rgba(7, 18, 36, 0.55);
  box-shadow: 0 10px 28px var(--shadow);
}

.install-step:not(:last-child)::after {
  content: '';
  position: absolute;
  top: 50%;
  right: -0.65rem;
  width: 0.9rem;
  height: 2px;
  border-radius: 999px;
  background: linear-gradient(90deg, rgba(77, 163, 255, 0.15), var(--sea));
  transform: translateY(-50%);
  pointer-events: none;
}

.install-step-mark {
  flex: 0 0 auto;
  display: grid;
  place-items: center;
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 12px;
  color: var(--sea);
  background: rgba(77, 163, 255, 0.14);
  border: 1px solid rgba(77, 163, 255, 0.28);
}

.install-step-copy {
  min-width: 0;
  display: grid;
  gap: 0.3rem;
}

.install-step-copy strong {
  font-family: var(--font-display);
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}

.install-step-copy p {
  margin: 0;
  color: var(--muted);
  font-size: 0.92rem;
  line-height: 1.45;
}

.install-step-copy a {
  color: var(--ink);
  text-decoration: underline;
  text-decoration-color: rgba(77, 163, 255, 0.45);
  text-underline-offset: 0.18em;
}

.install-step-copy a:hover {
  color: var(--sea);
}

.install-badge {
  display: inline-block;
  margin-left: 0.4rem;
  padding: 0.12rem 0.45rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  color: #1a1208;
  background: var(--accent);
  vertical-align: 0.1em;
}

.install-stage {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  width: min(520px, 100%);
  margin: 0 auto 1.75rem;
  padding: 1.35rem 1.5rem;
  border-radius: 20px;
  border: 1px solid var(--stroke);
  background:
    radial-gradient(ellipse 70% 80% at 20% 40%, rgba(255, 158, 72, 0.12), transparent 55%),
    radial-gradient(ellipse 70% 80% at 80% 50%, rgba(77, 163, 255, 0.16), transparent 55%),
    rgba(7, 18, 36, 0.65);
}

.install-stage-orb {
  display: grid;
  place-items: center;
  width: 8.5rem;
  height: 8.5rem;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: rgba(255, 255, 255, 0.03);
}

.install-stage-orb.apps {
  border-color: rgba(77, 163, 255, 0.28);
}

.install-app-tile,
.install-apps-tile {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.78rem;
  font-weight: 650;
  color: var(--ink);
  letter-spacing: -0.01em;
}

.install-app-tile {
  padding: 0.65rem 0.75rem;
  border-radius: 14px;
  background: linear-gradient(180deg, #ffb36a, var(--accent));
  color: #1a1208;
  box-shadow: 0 8px 20px rgba(255, 158, 72, 0.28);
}

.install-app-tile img {
  border-radius: 7px;
}

.install-stage-arrow {
  color: var(--sea);
  flex: 0 0 auto;
  opacity: 0.85;
  animation: install-nudge 2.4s ease-in-out infinite;
}

@keyframes install-nudge {
  0%,
  100% {
    transform: translateX(0);
    opacity: 0.55;
  }
  50% {
    transform: translateX(6px);
    opacity: 1;
  }
}

@media (prefers-reduced-motion: reduce) {
  .install-stage-arrow {
    animation: none;
    opacity: 0.85;
  }
}

.install-ctas {
  justify-content: center;
  flex-wrap: wrap;
  margin-bottom: 1.5rem;
}

@media (max-width: 820px) {
  .install-path {
    grid-template-columns: minmax(0, 1fr);
    gap: 0.75rem;
  }

  .install-step:not(:last-child)::after {
    display: none;
  }

  .install-stage {
    gap: 0.65rem;
    padding: 1.1rem;
  }

  .install-stage-orb {
    width: 7rem;
    height: 7rem;
  }

  .install-stage-arrow {
    width: 48px;
  }
}

.brew-box {
  width: min(640px, 100%);
  margin: 0 auto;
  padding: 1.15rem 1.25rem;
  text-align: left;
  border-radius: 16px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
}

.brew-box-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.brew-box h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.1rem;
}

.brew-copy-btn {
  appearance: none;
  margin: 0;
  padding: 0.35rem 0.7rem;
  border: 1px solid var(--stroke);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.05);
  color: var(--muted);
  font: inherit;
  font-size: 0.82rem;
  font-weight: 650;
  cursor: pointer;
  transition: color 0.15s ease, border-color 0.15s ease, background 0.15s ease;
}

.brew-copy-btn:hover {
  color: var(--ink);
  border-color: rgba(77, 163, 255, 0.45);
}

.brew-copy-btn:focus-visible {
  outline: 2px solid var(--sea);
  outline-offset: 2px;
}

.brew-copy-btn.copied {
  color: #9fe0b8;
  border-color: rgba(159, 224, 184, 0.4);
  background: rgba(80, 200, 120, 0.12);
}

.brew-box p {
  margin: 0.4rem 0 0.75rem;
  color: var(--muted);
  font-size: 0.95rem;
}

.brew-box pre {
  margin: 0;
  padding: 0.85rem 1rem;
  overflow-x: auto;
  border-radius: 12px;
  background: rgba(7, 18, 36, 0.75);
  color: var(--ink);
  font-size: 0.88rem;
  line-height: 1.45;
}

.cli-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
  margin-bottom: 1.25rem;
}

.cli-grid .brew-box {
  width: auto;
  margin: 0;
}

.cli-usage-box {
  width: min(100%, 100%);
  margin: 0 0 1.25rem;
}

.cli-usage-box pre {
  max-height: none;
}

.fine a {
  color: var(--sea);
  text-decoration: none;
}

.fine a:hover {
  text-decoration: underline;
}

.cli-note {
  margin-top: 0.85rem !important;
  font-size: 0.88rem !important;
  line-height: 1.45;
}

.cli-note a {
  color: var(--sea);
  text-decoration: none;
}

.cli-note a:hover {
  text-decoration: underline;
}

.cli-note code {
  display: inline;
  word-break: break-all;
  font-size: 0.82rem;
  color: var(--ink);
}

.cli-keys {
  padding: 1.15rem 1.25rem;
  border-radius: 16px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.03);
}

.cli-keys h3 {
  margin: 0 0 0.75rem;
  font-family: var(--font-display);
  font-size: 1.1rem;
}

.cli-keys ul {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.55rem 1rem;
  margin: 0 0 0.9rem;
  padding: 0;
  list-style: none;
  color: var(--muted);
  font-size: 0.92rem;
}

.cli-keys li {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.35rem;
}

.cli-keys kbd {
  display: inline-block;
  min-width: 1.5rem;
  padding: 0.15rem 0.4rem;
  border-radius: 6px;
  border: 1px solid var(--stroke);
  background: rgba(7, 18, 36, 0.75);
  color: var(--ink);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.78rem;
  text-align: center;
}

.cli-keys p {
  margin: 0;
  color: var(--muted);
  font-size: 0.95rem;
  line-height: 1.5;
}

.cli-keys code {
  font-size: 0.88rem;
  color: var(--ink);
}

@media (max-width: 820px) {
  .cli-grid {
    grid-template-columns: minmax(0, 1fr);
  }

  .cli-keys ul {
    grid-template-columns: minmax(0, 1fr);
  }
}

.footer {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 0.75rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--stroke);
  color: var(--faint);
  font-size: 0.92rem;
}

.footer div {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.footer strong {
  color: var(--ink);
  font-family: var(--font-display);
}

@keyframes rise {
  from {
    opacity: 0;
    transform: translateY(14px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes float-in {
  from {
    opacity: 0;
    transform: translateY(18px) scale(0.98);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@media (prefers-reduced-motion: reduce) {
  .top,
  .hero-copy,
  .hero-visual,
  .btn {
    animation: none !important;
    transition: none !important;
  }
}

@media (max-width: 960px) {
  .page {
    width: min(1180px, calc(100% - 1.5rem));
  }

  .hero,
  .feature-scene,
  .feature-scene.flip {
    grid-template-columns: minmax(0, 1fr);
  }

  .feature-scene.flip .feature-copy,
  .feature-scene.flip .feature-stage {
    order: initial;
  }

  .feature-scene {
    padding: 1.25rem;
    gap: 1.25rem;
  }

  .cards,
  .cat-list {
    grid-template-columns: minmax(0, 1fr);
  }

  .nav a:not(.nav-ghost) {
    display: none;
  }

  .feature-jump {
    position: static;
  }
}
</style>
