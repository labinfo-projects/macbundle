# macOS Deployment & Icon Toolkit

Una raccolta di tre strumenti da riga di comando per macOS, completamente autonomi e privi di dipendenze esterne. Il toolkit copre l'intero flusso di lavoro: dal recupero di icone storiche (anche da vecchi formati Classic Mac OS) alla creazione di applicazioni `.app` native firmate, fino alla generazione di immagini disco `.dmg` compresse con layout grafico trascinabile verso `/Applications`.

---

## 📦 Contenuto del repository

| File | Linguaggio | Scopo |
| :--- | :--- | :--- |
| **`converticons.swift`** | Swift | Estrazione batch di icone ad alta risoluzione con canale alfa da file e cartelle legacy. |
| **`bundlemyapp.sh`** | Bash | Creazione di bundle `.app` nativi con iconset Retina multi-risoluzione e firma ad-hoc. |
| **`creaDMG.sh`** | Bash / AppleScript | Creazione di file `.dmg` compressi (UDZO) con impostazione visiva drag-and-drop. |

---

## ⚙️ Requisiti di sistema

Gli script utilizzano esclusivamente gli strumenti di sistema preinstallati su macOS e le **Xcode Command Line Tools**. Non occorre installare pacchetti Python, Node.js o formule Homebrew.

Se non hai ancora installato gli strumenti da riga di comando di Xcode:
```bash
xcode-select --install
```

### Strumenti di sistema impiegati
* **Swift runtime** (`swift`) per interrogare le API di sistema `AppKit` / `Cocoa`.
* **Image Processing**: `sips` e `iconutil` per la manipolazione grafica e la compilazione `.icns`.
* **Disk Images**: `hdiutil`, `plutil` e `diskutil` per la creazione e formattazione dei volumi.
* **Automazione interfaccia**: `osascript` (AppleScript) per impostare la posizione degli elementi nel Finder.
* **Sicurezza**: `codesign` e `xattr` per la firma ad-hoc e la rimozione dei flag di quarantena.

---

## 🚀 Guida all'uso

Prima di iniziare, rendi eseguibili gli script Bash:
```bash
chmod +x bundlemyapp.sh creaDMG.sh
```

---

### 1. `converticons.swift` — Recupero icone da Resource Fork

Estrae le icone incorporate negli attributi estesi (`com.apple.ResourceFork`) o nei vecchi file a doppio fork tipici di Mac OS 9 e OS X Tiger/Panther (file a 0 byte con attributo `@`), convertendole in immagini PNG trasparenti a 32 bit (RGBA).

#### Caratteristiche:
* Interroga `NSWorkspace.shared.icon(forFile:)` per ottenere la rappresentazione ufficiale a più alta risoluzione disponibile (128×128, 256×256 o superiore).
* Pulisce esplicitamente il buffer grafico (`cgContext.clear`) evitando che la trasparenza venga fusa su sfondi bianchi o neri.
* Elabora automaticamente tutti i file e le cartelle presenti nella directory corrente, salvando i risultati in una sottocartella dedicata.

#### Esecuzione:
Posiziona lo script nella cartella contenente i file con le icone ed eseguilo:
```bash
swift converticons.swift
```

I file generati verranno salvati in:
```text
./png_alta_risoluzione/
├── NomeIcona1.png
├── NomeIcona2.png
└── ...
```

---

### 2. `bundlemyapp.sh` — Creazione del Bundle Applicazione (.app)

Trasforma qualsiasi file binario eseguibile (compilato in Rust, C, C++, Go, Zig o generato con PyInstaller/Nuitka) in un bundle macOS `.app` standard pronto per l'esecuzione.

#### Caratteristiche:
* **Supporto PNG o ICNS**: Se fornisci un PNG, lo script genera automaticamente un `.iconset` completo a 10 risoluzioni (da 16×16 a 512×512@2x per schermi Retina) e lo compila in un file `AppIcon.icns` tramite `iconutil`.
* **Configurazione Info.plist**: Genera un file `Info.plist` con metadati essenziali e la chiave `<key>NSHighResolutionCapable</key><true/>` per abilitare la nitidezza Retina.
* **Firma del codice**: Rimuove gli attributi di quarantena e applica una firma ad-hoc (`codesign --sign -`) per consentire l'avvio dell'applicazione su macOS moderno.

#### Sintassi:
```bash
./bundlemyapp.sh <percorso_eseguibile> <icona.png | icona.icns>
```

#### Esempio:
```bash
./bundlemyapp.sh ./target/release/mia_app ./assets/AppIcon.png
```
*Output generato: `mia_app.app`*

---

### 3. `creaDMG.sh` — Creazione dell'Installer .DMG

Genera un file `.dmg` compresso e pronto per la distribuzione, configurato con il collegamento alla cartella `/Applications` e un layout grafico posizionato per il trascinamento.

#### Caratteristiche:
* Formatta il volume temporaneo con filesystem **HFS+**, indispensabile affinché il Finder salvi correttamente le impostazioni visive del layout nel file `.DS_Store`.
* Assegna al volume montato la stessa icona personalizzata definita all'interno dell'applicazione (`.VolumeIcon.icns`).
* Configura tramite AppleScript le dimensioni della finestra e le posizioni relative di:
  * Icona applicazione (a sinistra).
  * Collegamento simbolico ad `/Applications` (a destra).
* Gestisce in sicurezza il rilascio dei descrittori di file e dei blocchi kernel prima della conversione finale in formato compresso di sola lettura (`UDZO` zlib level 9).

#### Sintassi:
```bash
./creaDMG.sh <NomeApp.app> [NomeVolumeOpzionale]
```

#### Esempio:
```bash
./creaDMG.sh mia_app.app "Installa Mia App"
```
*Output generato: `mia_app.dmg`*

---

## 🔄 Flusso di lavoro completo (Pipeline)

Ecco un esempio tipico di compilazione e rilascio end-to-end (ad esempio per un progetto Rust):

```bash
# 1. Compila il binario in modalità release
cargo build --release

# 2. Crea il bundle .app partendo dall'eseguibile e dal logo PNG
./bundlemyapp.sh target/release/mia_app assets/logo.png

# 3. Genera il file .dmg per la distribuzione
./creaDMG.sh mia_app.app "Mia App Installer"

# 4. Verifica il risultato aprendo il disco
open mia_app.dmg
```

---

## 🛠️ Risoluzione dei problemi

### La finestra del DMG non salva le posizioni delle icone
macOS memorizza le posizioni visive nel file nascosto `.DS_Store`. Affinché ciò avvenga:
1. Il filesystem dell'immagine deve essere `HFS+` e non `APFS`.
2. Il volume deve essere montato sotto `/Volumes/` e manipolato tramite il Finder prima dello smontaggio (processo gestito in automatico da `creaDMG.sh`).

### Avvisi di deprecazione di `hdiutil`
Su versioni recenti di macOS (macOS 15 Sequoia e successive), alcuni sottocomandi di `hdiutil` mostrano warning suggerendo `diskutil image`. Tuttavia, `diskutil image create blank` non supporta `HFS+` (necessario per i DMG di installazione). `creaDMG.sh` filtra automaticamente tali messaggi informativi mantenendo la massima compatibilità retroattiva.

---

## 📄 Licenza

Questo progetto è rilasciato sotto licenza [MIT](https://github.com/labinfo-projects/macbundle/blob/main/LICENSE). Sentiti libero di utilizzare, modificare e integrare questi script nei tuoi flussi di compilazione.
