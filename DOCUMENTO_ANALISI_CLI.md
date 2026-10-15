# Documento di analisi: CLI MacCleaner

## 1. Obiettivo

Esporre le funzionalità di cleanup già presenti nell’app SwiftUI come **CLI nativa** (`maccleaner`), con:

- scan e report su stdout
- `--dry-run` obbligatorio come default per le azioni distruttive
- riuso degli stessi engine della GUI (`ScanEngine`, `Cleaner`, cataloghi app, ecc.)
- zero telemetria, stessi limiti di privacy del prodotto

Non è obiettivo di questa CLI orchestrare gli script di packaging in `Scripts/` (quello resta workflow di sviluppo).

## 2. Stato attuale

| Pezzo | Ruolo |
|---|---|
| `OpenCleanMyMac/` | App macOS SwiftUI (SPM executable) — prodotto principale |
| `pages/` + Nuxt | Solo landing site (GitHub Pages) |
| `Scripts/` | Build, notarize, install locale — **dev tooling**, non product CLI |
| Headless flags | Smoke check già nel binario |

### Implementato (in-tree)

- Product SPM: `OpenCleanMyMac` + `maccleaner` (stesso target)
- Entry: `CLI/CLIBootstrap.swift` + `CLI/MacCleanerCLI.swift` (ArgumentParser)
- TUI: `CLI/TUI/` — workspace + selezione tastiera + `--plain`
- Sottocomandi: `scan`, `clean`, `apps`, `orphans`, `doctor` (+ `--version` / `--help`)
- Legacy: `--scan-once` → `scan`, `--apps-once` → `apps`, `--perf-once` / `--priv-once` → `doctor --perf|--priv`
- `maccleaner` senza args → workspace interattivo (TTY); `clean` senza flag → review interattiva

```bash
cd OpenCleanMyMac && swift build
.build/debug/maccleaner
.build/debug/maccleaner clean
.build/debug/maccleaner scan --json
.build/debug/maccleaner clean --dry-run
```

PATH via symlink dall’app (documentato in README + sito). Ancora aperto: formula Homebrew dedicata per la sola CLI.

## 3. Cosa non fare

- **CLI Node** (`cac` / `commander`) che wrappa Bash o riscrive la logica di scan → diverge dalla GUI, non riusa `ScannerRegistry` / `Cleaner`.
- Elevazione generica via `sudo` da script esterni → bypassa allowlist e prompt già definiti in `PrivilegedBridge` / `docs/PRIVILEGED_HELPER.md`.
- Accoppiare packaging (`package-app.sh`, notarize) al comando utente `maccleaner`.

## 4. Architettura proposta

### 4.1 Stack

- **Linguaggio:** Swift (stesso target o target executable affiancato)
- **Parsing argomenti:** [`swift-argument-parser`](https://github.com/apple/swift-argument-parser) (standard Apple)
- **Alternativa minima:** estendere il parsing argv manuale già usato per `--*-once` (ok per MVP, meno comodo per help/subcomandi)

`cac` / `commander` **non** sono candidati per la CLI prodotto.

### 4.2 Forma del comando

Nome pubblico: `maccleaner` (symlink o product SPM dedicato nel bundle / PATH).

```text
maccleaner                                 # workspace TUI (TTY)
maccleaner --plain                         # menu numerato
maccleaner scan [--category <id>] [--json]
maccleaner clean                           # TUI select → yes → Trash
maccleaner clean --dry-run [--category <id>]
maccleaner clean --confirm [--category <id>]   # selezione default, no TUI
maccleaner apps [--leftovers]
maccleaner orphans                         # TUI su TTY; altrimenti solo lista
maccleaner orphans --dry-run|--confirm
maccleaner doctor
```

Compatibilità: i flag `--scan-once` ecc. restano o diventano alias deprecati di `scan` / `apps` / `doctor`.

### 4.3 Riuso codice

```text
CLI (ArgumentParser)
  → ScanEngine / ScannerRegistry     (scan)
  → Cleaner.moveToTrash(..., isCancelled:)  (clean, con dry-run che non chiama trash)
  → ApplicationsCatalog / LeftoverDiscovery
  → PrivilegedBridge.statusSummary()  (doctor; nessuna azione elevate dalla CLI v1)
```

Output:

- testo umano su stdout (default)
- `--json` opzionale per automazione
- errori su stderr + exit code ≠ 0

### 4.4 Packaging / distribuzione

Opzioni (in ordine di pragmatismo):

1. **MVP:** stesso binary dell’app; se argv è un sottocomando CLI, non aprire UI (come oggi coi flag headless).
2. **v1.1:** product SPM `maccleaner` che dipende dal codice Core, installabile in `/usr/local/bin` o via Homebrew formula (oltre al cask GUI).
3. Symlink `MacCleaner.app/Contents/MacOS/…` → `maccleaner` documentato in README.

## 5. Comportamento sicurezza e dry-run

| Azione | Default | Note |
|---|---|---|
| `scan` | solo lettura | OK senza conferma |
| `clean` | richiede `--dry-run` **oppure** `--confirm` | senza flag → errore e help |
| Path system elevate | **fuori scope v1** | resta GUI + bridge allowlisted; CLI non inventa `sudo` |
| Esclusioni | rispettare `CleanupExclusions` | stessa policy della GUI |
| AI / large-old | mai auto-selezionati | come Smart Care |

Dry-run stampa path + byte che *verrebbero* spostati nel Cestino, senza chiamare `trashItem`.

## 6. Piano di azione

1. **MVP parsing** — ArgumentParser (o argv esteso): `scan`, `version`, `doctor`; mappare `--scan-once` → `scan`.
2. **Output** — tabella testo + `--json` minimo su `scan`.
3. **`clean --dry-run`** — riuso selezione default Smart Care (categorie cleanable, senza AI/large-old).
4. **`clean --confirm`** — Trash solo dopo conferma; progress su stderr; cancellabile con SIGINT tra item.
5. **`apps` / `orphans`** — promuovere `HeadlessApps` a sottocomandi stabili.
6. **Distribuzione** — documentare invocazione; poi formula/symlink PATH.
7. **Test** — smoke in CI: `maccleaner scan --json` exit 0 su runner macOS.

Fuori scope v1: auto-complete shell (nice-to-have), SMAppService, clean di path di sistema.

## 7. Scelta libreria (sintesi)

| Opzione | Ruolo |
|---|---|
| **swift-argument-parser** | **Scelta consigliata** per CLI prodotto |
| Argv manuale | Accettabile solo per MVP strettissimo |
| cac / commander (Node) | Solo eventuale wrapper **dev** su `Scripts/` — non la CLI MacCleaner |

## 8. Criteri di successo

- Stesso risultato qualitativo di uno Smart Care “solo lettura” via `maccleaner scan`
- Nessuna cancellazione senza `--confirm`
- Nessuna dipendenza Node runtime per l’utente finale
- README aggiornato con esempi; sito può citare la CLI quando esiste un binario installabile
