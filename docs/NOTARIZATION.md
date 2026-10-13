# Firma Developer ID e notarizzazione

Obiettivo: chi scarica `MacCleaner.app.zip` **non** vede il popup Gatekeeper.

## Cosa serve

1. **Apple Developer Program** (ce l’hai)
2. Certificato **Developer ID Application** (diverso da Development / Distribution App Store)
3. Credenziali **notarytool** (Apple ID + password app-specific, oppure API key)

Sul Mac ora risultano certi *Development* e *Apple Distribution*, ma **manca** ancora:

`Developer ID Application: … (T6EB446J72)`

Senza quello la notarizzazione per download web non parte.

## 1. Crea il certificato Developer ID

1. Apri [Certificates](https://developer.apple.com/account/resources/certificates/list)  
2. **+** → **Developer ID Application**  
3. Segui la CSR (Keychain Access → Certificate Assistant → Request from CA)  
4. Scarica il `.cer` e fai doppio clic per installarlo nel login keychain  
5. Verifica:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

## 2. Password app-specific (se usi Apple ID)

1. [appleid.apple.com](https://appleid.apple.com) → Accedi → **Password app-specific**  
2. Generane una per “MacCleaner notary”  
3. Salva il profilo una sola volta:

```bash
xcrun notarytool store-credentials "maccleaner-notary" \
  --apple-id "TUAemail@…" \
  --team-id "T6EB446J72" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

Oppure copia `.env.notarize.example` → `.env.notarize` e compila.

## 3. Build + firma + notarizza

```bash
./Scripts/package-app.sh
./Scripts/sign-and-notarize.sh
```

Lo script:

- firma con Hardened Runtime + timestamp  
- notarizza l’app, poi il **DMG**  
- fa **stapler** su `.app` e `.dmg`  
- rigenera `releases/MacCleaner-<version>.{dmg,zip}` (+ alias stabili) e aggiorna `Casks/maccleaner.rb`

Poi commit/push dello zip aggiornato (o pubblica una GitHub Release).

## 4. Verifica locale

```bash
spctl --assess --type execute -vv dist/MacCleaner.app
codesign -dv --verbose=4 dist/MacCleaner.app
```

Atteso: `accepted` / autorità `Developer ID Application` + ticket staple.

## Note

- **Apple Distribution** serve all’App Store, non ai download dal sito.  
- Team ID usato di default: `T6EB446J72` (override con `APPLE_TEAM_ID`).  
- Non committare `.env.notarize` né file `.p8`.
