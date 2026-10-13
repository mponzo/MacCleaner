# Firma Developer ID e notarizzazione

Obiettivo: chi scarica il DMG/ZIP **non** vede il popup Gatekeeper (“Apple non è in grado di verificare…”).

## Stato sul Mac di sviluppo

Hai già:

```text
Developer ID Application: Matteo Ponzo (T6EB446J72)
```

Manca solo il profilo **notarytool** (credenziali Apple per la notarizzazione). Finché non c’è, `package-app.sh` firma correttamente ma Gatekeeper blocca i download da internet.

## Workaround locale (subito)

Dopo aver trascinato l’app in Applicazioni:

```bash
./Scripts/clear-quarantine.sh ~/Applications/MacCleaner.app
# oppure
xattr -cr ~/Applications/MacCleaner.app && open ~/Applications/MacCleaner.app
```

Oppure: clic destro su MacCleaner → **Apri** → conferma. Su macOS recenti a volte serve anche Impostazioni di Sistema → Privacy e sicurezza → **Apri comunque**.

`./Scripts/install.sh` (build locale) rimuove già la quarantine in automatico.

## 1. Salva le credenziali notary (una volta)

Password app-specific: [appleid.apple.com](https://appleid.apple.com) → Accedi → **Password app-specific**.

```bash
xcrun notarytool store-credentials "maccleaner-notary" \
  --apple-id "TUAemail@…" \
  --team-id "T6EB446J72" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Oppure copia `.env.notarize.example` → `.env.notarize` e compila (non commitare).

## 2. Build + firma + notarizza

```bash
./Scripts/package-app.sh
./Scripts/sign-and-notarize.sh
```

Lo script firma con Hardened Runtime, notarizza app + DMG, fa **stapler**, aggiorna `releases/` e il cask.

## 3. Verifica

```bash
spctl --assess --type execute -vv dist/MacCleaner.app
# atteso: accepted
xcrun stapler validate dist/MacCleaner.app
```

## Note

- **Apple Distribution** = App Store; per download web serve **Developer ID Application** + notarizzazione.  
- Team ID default: `T6EB446J72`.  
- Non committare `.env.notarize` né file `.p8`.
