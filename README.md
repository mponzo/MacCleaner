<p align="center">
  <img src="docs/assets/maccleaner-banner.svg" alt="MacCleaner — pulizia locale, percorsi trasparenti, controllo totale" width="920"/>
</p>

<h1 align="center">MacCleaner</h1>

<p align="center">
  <strong>Riprendi spazio sul Mac.</strong><br/>
  Pulitore <strong>open-source</strong>, nativo SwiftUI: Smart Care, disinstallazione, prestazioni e manutenzione.<br/>
  <strong>Zero telemetria. Zero account. Zero cloud.</strong> Tutto resta sul tuo Mac.
</p>

<p align="center">
  <img alt="Zero telemetry" src="https://img.shields.io/badge/telemetria-zero-2E6BD1?style=for-the-badge"/>
  <img alt="Privacy first" src="https://img.shields.io/badge/privacy-100%25%20locale-0A1A33?style=for-the-badge"/>
  <img alt="MIT" src="https://img.shields.io/badge/license-MIT-FF9E48?style=for-the-badge"/>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-4DA3FF?style=flat-square"/>
  <img alt="SwiftUI" src="https://img.shields.io/badge/SwiftUI-SPM-4DA3FF?style=flat-square"/>
  <img alt="IT / EN" src="https://img.shields.io/badge/lingua-IT%20%7C%20EN-0A1A33?style=flat-square"/>
  <img alt="No analytics" src="https://img.shields.io/badge/analytics-none-2E6BD1?style=flat-square"/>
  <img alt="No subscription" src="https://img.shields.io/badge/abbonamento-nessuno-2E6BD1?style=flat-square"/>
</p>

<p align="center">
  <a href="releases/MacCleaner.app.zip"><strong>Scarica MacCleaner.app.zip</strong></a> ·
  <a href="#fiducia-verificabile">Privacy</a> ·
  <a href="#funzionalità">Funzionalità</a> ·
  <a href="#installazione">Installazione</a> ·
  <a href="#sicurezza-e-privilegi">Sicurezza</a>
</p>

---

## Fiducia verificabile

Un cleaner per Mac può vedere file sensibili e chiedere privilegi elevati. Merita trasparenza, non slogan. Questo è il contratto di MacCleaner — e puoi controllarlo nel codice sorgente:

| Impegno | Cosa significa |
|---|---|
| **Nessuna telemetria, mai** | Niente analytics, crash reporter di terze parti, “statistiche anonime”, account o phone-home. L’app **non sa chi sei**. |
| **Nessuna rete verso di noi** | Scansioni e pulizie funzionano **offline**. Non carichiamo percorsi, elenchi file o dati cancellati. |
| **Niente urgenza finta** | Nessun allarme rosso del tipo “il Mac è a rischio”. Mostriamo dimensioni e percorsi neutri: decidi tu. |
| **Selezione esplicita** | Niente “pulisci tutto” cieco. Vedi i path, spunti cosa liberare, puoi **Stop** durante scansione/pulizia. |
| **Cestino per le pulizie utente** | Gli item utente selezionati vanno nel **Cestino** di macOS (`trashItem`), non in un delete silenzioso nascosto. |
| **Admin solo su allowlist** | Cache/log di sistema e simili passano da un bridge con password e percorsi **consentiti esplicitamente**. |
| **Open source (MIT)** | Codice leggibile, forkabile, auditabile. Se un giorno aggiungesse telemetria o paywall sulle funzioni base, tradirebbe questo contratto. |

### Cosa MacCleaner **non** fa

- Non raccoglie telemetria, crash report o usage analytics  
- Non richiede account, login o abbonamento  
- Non carica su server esterni i percorsi scansionati o i file eliminati  
- Non si presenta come antivirus / scanner malware  
- Non promette “boost RAM” o magie sullo spazio purgeable APFS  

---

## Indice

1. [Fiducia verificabile](#fiducia-verificabile)  
2. [Perché MacCleaner](#perché-maccleaner)  
3. [Requisiti](#requisiti)  
4. [Funzionalità](#funzionalità)  
5. [Interfaccia e lingua](#interfaccia-e-lingua)  
6. [Installazione](#installazione)  
7. [Sviluppo e CLI](#sviluppo-e-cli)  
8. [Sicurezza e privilegi](#sicurezza-e-privilegi)  
9. [Roadmap](#roadmap)  
10. [Licenza](#licenza)  

---

## Perché MacCleaner

Molti cleaner commerciali nascondono la logica dietro abbonamenti, telemetria e messaggi alarmisti. MacCleaner è l’opposto:

- **Installazione una tantum** — niente trial, niente account  
- **Zero telemetria** — non chiama casa; non sa che esisti  
- **MIT open source** — leggi, verifica, modifica  
- **Scansioni oneste** — cache, leftover, DerivedData, log: fatti misurabili, non paura  
- **Disinstallazioni reali** — residui in Library (prefs, cache, container, agent…) con selezione esplicita  

MacCleaner è **locale e trasparente**: ogni elemento recuperabile mostra il percorso sul disco; le operazioni di sistema usano un bridge admin con **allowlist**.

| Principio | In pratica |
|---|---|
| Locale | Solo filesystem; nessuna telemetria di prodotto |
| Trasparente | Dimensioni, percorsi e categorie sempre visibili |
| Selettivo | Item per item, non “pulisci tutto” cieco |
| Interrompibile | **Stop** durante Smart Care o pulizia |
| Privato | Nessun analytics, nessun crash phone-home |
| Bilingue | Italiano e inglese (sistema o scelta in Impostazioni) |

---

## Requisiti

- **macOS 14** (Sonoma) o successivo  
- Binario universale (Apple Silicon + Intel) in [`releases/MacCleaner.app.zip`](releases/MacCleaner.app.zip)  
- Xcode / Swift solo se vuoi compilare dal sorgente  

---

## Funzionalità

### Smart Care

Scansione multi-categoria dello spazio recuperabile, con te al comando.

- **Avvia Smart Care** con avanzamento per categoria  
- Metriche: recuperabile, scansionato, stato  
- Moduli cliccabili → **dettaglio** categoria  
- **Pulisci selezionati** → solo ciò che hai spuntato, nel Cestino  
- **Stop** durante scansione o pulizia  

#### Categorie scansionate

| Categoria | Cosa misura | Note |
|---|---|---|
| Cache utente | `~/Library/Caches` | Pulibile |
| Log utente | `~/Library/Logs` | Pulibile |
| Cestino | `~/.Trash` | Pulibile |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Pulibile |
| Archivi Xcode | `~/Library/Developer/Xcode/Archives` | Pulibile |
| Cache sviluppatore | npm, Homebrew, pip, Gradle, Yarn, pnpm, Cargo… | Pulibile |
| Download vecchi | Download &gt; 30 giorni | Pulibile |
| Immagini disco | `*.dmg` / `*.iso` in Download | Pulibile |
| Cache browser | Safari / Chrome / Firefox / Edge | Pulibile |
| Cartelle grandi | Top cartelle Home | Solo lettura |
| Residui app | Prefs, cache, container orfani | Pulibile |
| Launch Agent non validi | Agent utente con binario mancante | Pulibile |
| Cache di sistema | `/Library/Caches` | Admin + allowlist |
| Log di sistema | `/Library/Logs`, `/var/log` | Admin + allowlist |
| Agent di sistema non validi | `/Library/LaunchAgents` | Admin + allowlist |

---

### Applicazioni

Disinstallazione consapevole con residui correlati.

- Elenco app utente (ricerca nome / bundle ID)  
- Dimensione bundle + residui  
- Leftover: Preferences, Caches, Application Support, Logs, Saved State, Cookies, Containers, Group Containers, Launch Agents, Crash Reporter  
- Toggle “Includi il bundle dell’app”  
- Pulizia **residui orfani**  
- App di sistema protette: uninstall disabilitato  

---

### Prestazioni

- Memoria, CPU, disco libero  
- Top processi per memoria  
- Launch Agent (rimozione solo dominio utente)  
- Manutenzione: DNS *(admin)*, Mail VACUUM, snapshot APFS *(admin)*, Launch Services  

---

### Helper privilegiato

- Bridge admin (prompt password)  
- Rescan cache/log/agent di sistema  
- DNS flush e thin snapshot  
- Solo percorsi in **allowlist**  
- Scaffold futuro `SMAppService` → `docs/PRIVILEGED_HELPER.md`  

---

### Space Lens

Barre delle categorie già scansionate: dove va lo spazio dopo Smart Care.

---

### Menu bar (one-click)

Pannello glass (non menu classico): stato Mac, disco/RAM/batteria/CPU, rete, attività, consiglio Smart Care, Apri / Impostazioni / **Esci**. Una sola finestra principale — niente istanze duplicate.

---

### Impostazioni

Lingua (Sistema / EN / IT), menu bar, Dock, avvio all’accesso, installazione in `~/Applications`, **Esci**.

---

## Interfaccia e lingua

Tema **dark blue-glass**. Stringhe in `en.lproj` / `it.lproj`.

| Scorciatoia | Azione |
|---|---|
| ⌘R | Avvia Smart Care |
| ⌘K | Pulisci selezionati |
| ⌘Q | Esci |
| ⇧⌘U | Aggiorna applicazioni |
| ⇧⌘P | Aggiorna prestazioni |

---

## Installazione

### Modo semplice (consigliato)

1. Scarica **[MacCleaner.app.zip](releases/MacCleaner.app.zip)** (già nel repo)  
2. Apri lo zip → trascina `MacCleaner.app` in **Applicazioni** (o `~/Applications`)  
3. Avvia l’app (al primo avvio: tasto destro → **Apri**, se Gatekeeper chiede conferma)

Oppure da Terminale, senza clonare il progetto:

```bash
curl -L -o MacCleaner.app.zip \
  https://github.com/mponzo/MacCleaner/raw/main/releases/MacCleaner.app.zip
unzip -o MacCleaner.app.zip
mkdir -p ~/Applications
mv -f MacCleaner.app ~/Applications/
xattr -dr com.apple.quarantine ~/Applications/MacCleaner.app 2>/dev/null || true
open ~/Applications/MacCleaner.app
```

### Dal sorgente

Serve la Swift toolchain. Clona il repo, poi:

```bash
./Scripts/install.sh       # compila, crea lo zip e copia in ~/Applications
# oppure passo per passo:
./Scripts/package-app.sh   # dist/MacCleaner.app + releases/MacCleaner.app.zip
./Scripts/uninstall.sh
```

Bundle id: `com.maccleaner.app` · target SPM: `OpenCleanMyMac` (solo nome tecnico di build).

---

## Sviluppo e CLI

```bash
cd OpenCleanMyMac
swift build
swift run
```

Headless (senza UI, utili per audit locali):

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

## Sicurezza e privilegi

### Privacy by design

| Domanda | Risposta |
|---|---|
| Invia dati a internet? | **No** per scan/clean (lavoro offline) |
| Telemetria / analytics? | **No** |
| Crash reporter remoto? | **No** |
| Account obbligatorio? | **No** |
| Codice ispezionabile? | **Sì** (MIT) |

### Comportamento distruttivo

- Pulizie utente → **Cestino** macOS  
- Sistema → bridge admin + **allowlist**  
- Selezione e conferma implicita (spunte) prima della pulizia  
- **Stop** interrompe la task in corso  
- Non è un antivirus  

Se trovi un problema di sicurezza, segnalalo in privato (non in issue pubbliche con PoC).

---

## Roadmap

- Daemon privilegiato firmato (`SMAppService`) al posto dei prompt osascript  
- Più copertura scanner e raffinamento UI  
- Lingue oltre IT/EN  

---

## Licenza

**MIT.** Usa, modifica, redistribuisci. L’unica richiesta tipica della licenza MIT è mantenere l’avviso di copyright.

> Se MacCleaner ti ha liberato spazio **senza** vendere i tuoi dati, è esattamente lo scopo del progetto.
