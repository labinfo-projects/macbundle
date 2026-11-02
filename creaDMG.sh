#!/bin/bash

set -e

if [ $# -lt 1 ]; then
    echo "Uso:"
    echo "  $0 <NomeApp.app> [NomeVolume]"
    exit 1
fi

APP_BUNDLE="$1"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Errore: bundle non trovato: $APP_BUNDLE"
    exit 1
fi

APP_NAME="$(basename "$APP_BUNDLE" .app)"
VOL_NAME="${2:-$APP_NAME}"
DMG_FINAL="${APP_NAME}.dmg"
DMG_TMP="temp_${APP_NAME}.dmg"
MOUNT_PATH="/Volumes/$VOL_NAME"

# Pulizia preventiva
rm -f "$DMG_FINAL" "$DMG_TMP"

# Stima dimensione con margine
APP_SIZE_MB=$(du -sm "$APP_BUNDLE" | awk '{print $1}')
DISK_SIZE_MB=$((APP_SIZE_MB + 30))

echo "Creazione immagine disco temporanea di ${DISK_SIZE_MB}MB..."
hdiutil create -size "${DISK_SIZE_MB}m" -fs HFS+ -volname "$VOL_NAME" -ov "$DMG_TMP" 2>&1 | grep -v "WARNING:" || true

# Se per caso era rimasto montato un vecchio volume omonimo, lo espelliamo
if [ -d "$MOUNT_PATH" ]; then
    diskutil unmount force "$MOUNT_PATH" >/dev/null 2>&1 || true
fi

echo "Montaggio immagine disco in $MOUNT_PATH..."
# Estrae il /dev/diskX preciso tramite l'output plist
ATTACH_PLIST=$(hdiutil attach "$DMG_TMP" -nobrowse -noverify -noautoopen -plist 2>/dev/null)
DEV_NAME=$(echo "$ATTACH_PLIST" | plutil -extract system-entities.0.dev-entry raw - 2>/dev/null || true)

if [ -z "$DEV_NAME" ]; then
    # Fallback se plutil non estrae la chiave
    DEV_NAME=$(hdiutil attach "$DMG_TMP" -nobrowse -noverify -noautoopen | awk 'NR==1{print $1}')
fi

sleep 1

echo "Copia bundle e creazione link alla cartella Applicazioni..."
cp -R "$APP_BUNDLE" "$MOUNT_PATH/"
ln -s /Applications "$MOUNT_PATH/Applications"

if [ -f "$MOUNT_PATH/$APP_NAME.app/Contents/Resources/AppIcon.icns" ]; then
    cp "$MOUNT_PATH/$APP_NAME.app/Contents/Resources/AppIcon.icns" "$MOUNT_PATH/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_PATH" 2>/dev/null || true
fi

echo "Configurazione layout visivo tramite AppleScript..."
osascript <<EOF
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {300, 200, 850, 560}
        
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 104
        set arrangement of viewOptions to not arranged
        
        set position of item "$APP_NAME.app" of container window to {130, 160}
        set position of item "Applications" of container window to {410, 160}
        
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

sync
sleep 2

echo "Smontaggio volume..."
# Eseguiamo il detach e attendiamo il completo rilascio del device node
hdiutil detach "$DEV_NAME" -force 2>&1 | grep -v "WARNING:" || diskutil unmountDisk force "$DEV_NAME" >/dev/null 2>&1 || true

# Pausa di sicurezza affinché il processo DiskImages helper liberi il lock sul file
sleep 2

echo "Compressione finale in formato compresso (UDZO)..."
hdiutil convert "$DMG_TMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" 2>&1 | grep -v "WARNING:" || true
rm -f "$DMG_TMP"

if [ -f "$DMG_FINAL" ]; then
    echo
    echo "DMG creato con successo:"
    echo "  $DMG_FINAL ($(du -h "$DMG_FINAL" | awk '{print $1}'))"
else
    echo "Errore imprevisto durante la creazione del DMG."
    exit 1
fi
