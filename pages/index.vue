<script setup lang="ts">
const downloadUrl =
  'https://github.com/mponzo/MacCleaner/raw/main/releases/MacCleaner.app.zip'
const repoUrl = 'https://github.com/mponzo/MacCleaner'

const promises = [
  {
    title: 'Zero telemetria',
    body: 'Niente analytics, crash reporter o phone-home. L’app non sa chi sei.',
  },
  {
    title: 'Tutto in locale',
    body: 'Scansioni e pulizie funzionano offline. I tuoi percorsi restano sul Mac.',
  },
  {
    title: 'Percorsi visibili',
    body: 'Vedi cosa liberare, selezioni tu, puoi fermare in qualsiasi momento.',
  },
]

const features = [
  {
    title: 'Smart Care',
    body: 'Cache, log, leftover, DerivedData e altro — con Stop durante scansione o pulizia.',
  },
  {
    title: 'Applicazioni',
    body: 'Disinstalla con residui correlati: prefs, cache, container, agent.',
  },
  {
    title: 'Prestazioni',
    body: 'Memoria, CPU, disco e manutenzione (DNS, snapshot, Launch Services).',
  },
  {
    title: 'Aggiornamenti',
    body: 'Controlla e installa l’ultima build pubblicata sul repository GitHub.',
  },
]
</script>

<template>
  <div class="page">
    <header class="top">
      <a class="brand" href="#" aria-label="MacCleaner">
        <img src="/mark.svg" alt="" width="36" height="36" class="brand-icon" />
        <span>MacCleaner</span>
      </a>
      <nav class="nav">
        <a href="#privacy">Privacy</a>
        <a href="#funzioni">Funzioni</a>
        <a href="#installazione">Installazione</a>
        <a class="nav-ghost" :href="repoUrl" target="_blank" rel="noreferrer">GitHub</a>
      </nav>
    </header>

    <main>
      <section class="hero">
        <div class="hero-copy">
          <p class="eyebrow">Open source · macOS 14+</p>
          <h1 class="brand-hero">MacCleaner</h1>
          <p class="lede">
            Riprendi spazio sul Mac con percorsi trasparenti e controllo totale.
            Zero telemetria. Zero account. Zero cloud.
          </p>
          <div class="cta-row">
            <a class="btn btn-primary" :href="downloadUrl">Scarica per Mac</a>
            <a class="btn btn-ghost" :href="repoUrl" target="_blank" rel="noreferrer">
              Codice sorgente
            </a>
          </div>
          <p class="fine">Universale Apple Silicon + Intel · MIT · ~3&nbsp;MB</p>
        </div>
        <div class="hero-visual" aria-hidden="true">
          <div class="glow" />
          <img src="/banner.svg" alt="" class="hero-banner" />
        </div>
      </section>

      <section id="privacy" class="section">
        <div class="section-head">
          <h2>Fiducia verificabile</h2>
          <p>Un cleaner merita trasparenza, non slogan. Questo è il contratto.</p>
        </div>
        <div class="cards">
          <article v-for="item in promises" :key="item.title" class="card">
            <h3>{{ item.title }}</h3>
            <p>{{ item.body }}</p>
          </article>
        </div>
      </section>

      <section id="funzioni" class="section">
        <div class="section-head">
          <h2>Cosa fa</h2>
          <p>Strumenti locali, selezione esplicita, niente urgenza finta.</p>
        </div>
        <div class="feature-grid">
          <article v-for="item in features" :key="item.title" class="feature">
            <h3>{{ item.title }}</h3>
            <p>{{ item.body }}</p>
          </article>
        </div>
      </section>

      <section id="installazione" class="section install">
        <div class="section-head">
          <h2>Installazione</h2>
          <p>Tre passi. Non serve saper programmare.</p>
        </div>
        <img
          class="install-art"
          src="/install-steps.svg"
          alt="1 Scarica, 2 Installa in Applicazioni, 3 Apri MacCleaner"
          width="920"
          height="263"
        />
        <ol class="steps">
          <li>
            <strong>Scarica</strong>
            <span>il file MacCleaner.app.zip</span>
          </li>
          <li>
            <strong>Trascina</strong>
            <span>l’app in Applicazioni</span>
          </li>
          <li>
            <strong>Apri</strong>
            <span>tasto destro → Apri (non il doppio clic al primo avvio)</span>
          </li>
        </ol>
        <aside class="gatekeeper">
          <h3>Se macOS dice che non può verificarla</h3>
          <p>
            Normale per un’app open source non notarizzata. Clicca <strong>Fine</strong>,
            poi tasto destro su MacCleaner → <strong>Apri</strong> → conferma
            <strong>Apri</strong>. Oppure: Impostazioni → Privacy e sicurezza →
            <strong>Apri comunque</strong>.
          </p>
        </aside>
        <a class="btn btn-primary" :href="downloadUrl">Scarica MacCleaner.app.zip</a>
      </section>
    </main>

    <footer class="footer">
      <div>
        <strong>MacCleaner</strong>
        <span>MIT · privacy 100% locale</span>
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
  grid-template-columns: 1.05fr 0.95fr;
  gap: 2rem;
  align-items: center;
  min-height: min(72vh, 640px);
  margin-bottom: 4.5rem;
}

.hero-copy {
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
  font-family: var(--font-display);
  font-size: clamp(3.2rem, 8vw, 5.4rem);
  font-weight: 800;
  letter-spacing: -0.04em;
  line-height: 0.95;
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
  width: 100%;
  border-radius: 24px;
  border: 1px solid var(--stroke);
  box-shadow: 0 24px 60px var(--shadow);
  background: rgba(255, 255, 255, 0.03);
}

.section {
  margin-bottom: 4.25rem;
  animation: rise 0.8s ease both;
  animation-timeline: view();
  animation-range: entry 10% cover 30%;
}

.section-head {
  margin-bottom: 1.5rem;
  max-width: 40rem;
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

.cards,
.feature-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1rem;
}

.feature-grid {
  grid-template-columns: repeat(2, 1fr);
}

.card,
.feature {
  padding: 1.25rem 1.3rem;
  border-radius: 18px;
  border: 1px solid var(--stroke);
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.08), rgba(46, 107, 209, 0.12)),
    rgba(10, 26, 51, 0.35);
  box-shadow: 0 10px 30px rgba(3, 10, 24, 0.25);
  backdrop-filter: blur(14px);
}

.card h3,
.feature h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.15rem;
  letter-spacing: -0.02em;
}

.card p,
.feature p {
  margin: 0.55rem 0 0;
  color: var(--muted);
  line-height: 1.5;
  font-size: 0.98rem;
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

.gatekeeper {
  width: min(640px, 100%);
  margin: 0 auto 1.5rem;
  padding: 1.1rem 1.25rem;
  text-align: left;
  border-radius: 16px;
  border: 1px solid rgba(255, 158, 72, 0.35);
  background: rgba(255, 158, 72, 0.08);
}

.gatekeeper h3 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.05rem;
  color: var(--accent);
}

.gatekeeper p {
  margin: 0.45rem 0 0;
  color: var(--muted);
  font-size: 0.95rem;
  line-height: 1.5;
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
  .hero {
    grid-template-columns: 1fr;
    min-height: auto;
  }

  .cards,
  .feature-grid,
  .steps {
    grid-template-columns: 1fr;
  }

  .nav a:not(.nav-ghost) {
    display: none;
  }
}
</style>
