<script setup lang="ts">
const version = '0.2.2'
const dmgUrl = `https://github.com/mponzo/MacCleaner/raw/main/releases/MacCleaner-${version}.dmg`
const zipUrl = `https://github.com/mponzo/MacCleaner/raw/main/releases/MacCleaner-${version}.zip`
const repoUrl = 'https://github.com/mponzo/MacCleaner'
const brewCommands = `brew tap mponzo/maccleaner https://github.com/mponzo/MacCleaner
brew trust mponzo/maccleaner
brew install --cask maccleaner`

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

const featureSections = [
  {
    id: 'smart-care',
    title: 'Smart Care',
    lede: 'Multi-category reclaimable-space scan — you stay in control.',
    points: [
      'Run Smart Care with per-category progress',
      'Metrics for reclaimable space, scanned size, and status',
      'Click a module to open category detail',
      'Clean selected items into the macOS Trash',
      'Stop during scan or cleanup',
    ],
    categories: [
      'User caches & logs',
      'Trash',
      'Xcode DerivedData & Archives',
      'Developer caches (npm, Homebrew, pip, Gradle, Yarn, pnpm, Cargo…)',
      'Old downloads & disk images',
      'Browser caches (Safari, Chrome, Firefox, Edge)',
      'App leftovers & invalid Launch Agents',
      'System caches / logs / agents (admin + allowlist)',
    ],
  },
  {
    id: 'applications',
    title: 'Applications',
    lede: 'Mindful uninstall with related leftovers — nothing removed by surprise.',
    points: [
      'Browse user apps; search by name or bundle ID',
      'See bundle size plus leftover size',
      'Leftovers across Preferences, Caches, Application Support, Logs, Saved State, Cookies, Containers, Group Containers, Launch Agents, Crash Reporter',
      'Toggle whether to include the app bundle itself',
      'Clean orphan leftovers left behind by removed apps',
      'System apps stay protected — uninstall disabled',
    ],
  },
  {
    id: 'performance',
    title: 'Performance',
    lede: 'A clear snapshot of load and a few safe maintenance tools.',
    points: [
      'Memory, CPU, and free disk at a glance',
      'Top processes by memory',
      'User Launch Agents (remove only in the user domain)',
      'Maintenance: DNS flush (admin), Mail VACUUM, APFS snapshot thinning (admin), Launch Services rebuild',
    ],
  },
  {
    id: 'privileged',
    title: 'Privileged helper',
    lede: 'Elevated work only through a password prompt and an explicit path allowlist.',
    points: [
      'Admin bridge for system caches, logs, and agents',
      'DNS flush and APFS snapshot thinning',
      'Only allowlisted paths — never arbitrary shell',
      'Roadmap: signed SMAppService daemon (see docs)',
    ],
  },
  {
    id: 'space-lens',
    title: 'Space Lens',
    lede: 'After Smart Care, see where reclaimable space sits across categories.',
    points: [
      'Category bars from the latest scan',
      'Quick visual sense of what dominates disk use',
    ],
  },
  {
    id: 'updates',
    title: 'Updates',
    lede: 'Install the build published on the open GitHub repository.',
    points: [
      'Compare local version with releases/version.json',
      'Download the release zip and install to ~/Applications',
      'Relaunch after update',
      'Network only to GitHub, and only when you check or open this section',
    ],
  },
  {
    id: 'menubar',
    title: 'Menu bar',
    lede: 'One-click glass status panel next to the clock.',
    points: [
      'Live tiles for disk, memory, battery, CPU, network, and activity',
      'Smart Care tip and quick actions',
      'Open main window, Settings, or Quit',
      'Single app instance — no duplicate windows',
    ],
  },
  {
    id: 'settings',
    title: 'Settings',
    lede: 'Keep MacCleaner out of the way until you need it.',
    points: [
      'Language: System, English, or Italian',
      'Show menu bar icon / hide Dock icon',
      'Launch at login',
      'Install or remove from ~/Applications',
    ],
  },
]
</script>

<template>
  <div class="page">
    <header class="top">
      <a class="brand" href="#" aria-label="MacCleaner">
        <img src="/icon.png" alt="" width="36" height="36" class="brand-icon" />
        <span>MacCleaner</span>
      </a>
      <nav class="nav">
        <a href="#privacy">Privacy</a>
        <a href="#features">Features</a>
        <a href="#install">Install</a>
        <a class="nav-ghost" :href="repoUrl" target="_blank" rel="noreferrer">GitHub</a>
      </nav>
    </header>

    <main>
      <section class="hero">
        <div class="hero-copy">
          <p class="eyebrow">Open source · macOS 14+</p>
          <h1 class="brand-hero">MacCleaner</h1>
          <p class="lede">
            Reclaim space on your Mac with visible paths and full control.
            Zero telemetry. Zero accounts. Zero cloud.
          </p>
          <div class="cta-row">
            <a class="btn btn-primary" :href="dmgUrl">Download MacCleaner {{ version }}</a>
            <a class="btn btn-ghost" :href="repoUrl" target="_blank" rel="noreferrer">
              Source code
            </a>
          </div>
          <p class="fine">
            Universal Apple silicon + Intel · MIT · DMG {{ version }}
          </p>
        </div>
        <div class="hero-visual" aria-hidden="true">
          <div class="glow" />
          <img src="/banner.svg" alt="" class="hero-banner" />
        </div>
      </section>

      <section id="privacy" class="section">
        <div class="section-head">
          <h2>Verifiable trust</h2>
          <p>A cleaner deserves transparency, not slogans. This is the contract.</p>
        </div>
        <div class="cards">
          <article v-for="item in promises" :key="item.title" class="card">
            <h3>{{ item.title }}</h3>
            <p>{{ item.body }}</p>
          </article>
        </div>
      </section>

      <section id="features" class="section">
        <div class="section-head">
          <h2>Features</h2>
          <p>Every tool is local, selective, and path-visible — no fake urgency.</p>
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

        <article
          v-for="section in featureSections"
          :id="section.id"
          :key="section.id"
          class="feature-block"
        >
          <div class="feature-block-head">
            <h3>{{ section.title }}</h3>
            <p>{{ section.lede }}</p>
          </div>
          <ul class="point-list">
            <li v-for="point in section.points" :key="point">{{ point }}</li>
          </ul>
          <div v-if="section.categories" class="cat-wrap">
            <p class="cat-label">Scan categories</p>
            <ul class="cat-list">
              <li v-for="cat in section.categories" :key="cat">{{ cat }}</li>
            </ul>
          </div>
        </article>
      </section>

      <section id="install" class="section install">
        <div class="section-head">
          <h2>Install</h2>
          <p>Pick DMG, Homebrew, or zip — same universal MacCleaner {{ version }} build.</p>
        </div>
        <img
          class="install-art"
          src="/install-steps.svg"
          alt="1 Download, 2 Install to Applications, 3 Open MacCleaner"
          width="920"
          height="263"
        />
        <ol class="steps">
          <li>
            <strong>Download</strong>
            <span>MacCleaner {{ version }} (DMG)</span>
          </li>
          <li>
            <strong>Drag</strong>
            <span>into Applications</span>
          </li>
          <li>
            <strong>Open</strong>
            <span>double-click MacCleaner</span>
          </li>
        </ol>
        <div class="cta-row install-ctas">
          <a class="btn btn-primary" :href="dmgUrl">Download MacCleaner {{ version }}</a>
          <a class="btn btn-ghost" :href="zipUrl">Download zip {{ version }}</a>
        </div>
        <div class="brew-box">
          <h3>Homebrew</h3>
          <p>Yes — install with a cask from this repo:</p>
          <pre><code>{{ brewCommands }}</code></pre>
        </div>
      </section>
    </main>

    <footer class="footer">
      <div>
        <strong>MacCleaner</strong>
        <span>MIT · 100% local privacy</span>
      </div>
      <a :href="repoUrl" target="_blank" rel="noreferrer">github.com/mponzo/MacCleaner</a>
    </footer>
  </div>
</template>

<style scoped>
.page {
  width: min(1120px, calc(100% - 2.5rem));
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
  /* Fallback vw, then cqi so the single-line title shrinks to the column. */
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
  margin-bottom: 1.5rem;
}

.feature-jump a {
  padding: 0.4rem 0.75rem;
  border-radius: 999px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
  color: var(--muted);
  font-size: 0.88rem;
  font-weight: 600;
}

.feature-jump a:hover {
  color: var(--ink);
  border-color: rgba(77, 163, 255, 0.45);
}

.feature-block {
  padding: 1.4rem 1.45rem;
  margin-bottom: 1rem;
  border-radius: 20px;
  border: 1px solid var(--stroke);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.07), rgba(46, 107, 209, 0.1)),
    rgba(10, 26, 51, 0.32);
  scroll-margin-top: 1.25rem;
}

.feature-block-head h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.35rem;
  letter-spacing: -0.02em;
}

.feature-block-head p {
  margin: 0.4rem 0 0;
  color: var(--muted);
  line-height: 1.5;
}

.point-list,
.cat-list {
  margin: 1rem 0 0;
  padding-left: 1.15rem;
  color: var(--muted);
  line-height: 1.55;
}

.point-list li + li,
.cat-list li + li {
  margin-top: 0.35rem;
}

.cat-wrap {
  margin-top: 1.15rem;
  padding-top: 1rem;
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

.install {
  text-align: center;
}

.install .section-head {
  margin-left: auto;
  margin-right: auto;
}

.install-art {
  width: min(920px, 100%);
  margin: 0 auto 1.5rem;
  border-radius: 20px;
  border: 1px solid var(--stroke);
  background: rgba(7, 18, 36, 0.45);
}

.steps {
  list-style: none;
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.85rem;
  padding: 0;
  margin: 0 0 1.5rem;
  text-align: left;
}

.steps li {
  display: grid;
  gap: 0.25rem;
  padding: 1rem 1.1rem;
  border-radius: 14px;
  border: 1px solid var(--stroke);
  background: rgba(255, 255, 255, 0.04);
}

.steps strong {
  font-family: var(--font-display);
}

.steps span {
  color: var(--muted);
  font-size: 0.92rem;
  line-height: 1.4;
}

.install-ctas {
  justify-content: center;
  margin-bottom: 1.5rem;
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

.brew-box h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.1rem;
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

@media (max-width: 900px) {
  .page {
    width: min(1120px, calc(100% - 1.5rem));
  }

  .hero {
    grid-template-columns: minmax(0, 1fr);
    min-height: auto;
  }

  .cards,
  .steps,
  .cat-list {
    grid-template-columns: minmax(0, 1fr);
  }

  .nav a:not(.nav-ghost) {
    display: none;
  }
}
</style>
