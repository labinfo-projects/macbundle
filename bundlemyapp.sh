#!/bin/bash

set -e

if [ $# -ne 2 ]; then
    echo "Uso:"
    echo "  $0 <eseguibile> <icona.png | icona.icns>"
    exit 1
fi

EXE="$1"
ICON="$2"

if [ ! -f "$EXE" ]; then
    echo "Errore: eseguibile non trovato: $EXE"
    exit 1
fi

if [ ! -f "$ICON" ]; then
    echo "Errore: icona non trovata: $ICON"
    exit 1
fi

APP_NAME="$(basename "$EXE")"
APP_DIR="${APP_NAME}.app"

# Estensione dell'icona in minuscolo
ICON_EXT="${ICON##*.}"
ICON_EXT="$(echo "$ICON_EXT" | tr '[:upper:]' '[:lower:]')"

# Creazione della struttura interna del bundle
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copia e permessi per l'eseguibile
cp "$EXE" "$APP_DIR/Contents/MacOS/"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Gestione dell'icona (.png o .icns)
if [ "$ICON_EXT" = "png" ]; then
    TMP_DIR="$(mktemp -d /tmp/appicon.XXXXXX)"
    ICONSET="$TMP_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET"

    # Generazione dei vari tagli di risoluzione per monitor standard e Retina
    sips -z 16 16     "$ICON" --out "$ICONSET/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     "$ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     "$ICON" --out "$ICONSET/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     "$ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   "$ICON" --out "$ICONSET/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   "$ICON" --out "$ICONSET/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   "$ICON" --out "$ICONSET/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 "$ICON" --out "$ICONSET/icon_512x512@2x.png" >/dev/null 2>&1

    # Compilazione del file .icns finale
    iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
    rm -rf "$TMP_DIR"
elif [ "$ICON_EXT" = "icns" ]; then
    cp "$ICON" "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "Errore: il file icona deve avere estensione .png oppure .icns"
    exit 1
fi

# Generazione di Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>

    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>

    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>

    <key>CFBundleIdentifier</key>
    <string>com.mionome.$APP_NAME</string>

    <key>CFBundleVersion</key>
    <string>1.0</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleIconFile</key>
    <string>AppIcon</string>

    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Rimozione attributi di quarantena e firma ad-hoc
xattr -cr "$APP_DIR" 2>/dev/null || true

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

# Aggiornamento timestamp per forzare il refresh della cache icone del Finder
touch "$APP_DIR"

echo
echo "Creato bundle:"
echo "  $APP_DIR"
