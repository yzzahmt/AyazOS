set -e
# Kaynak: /veloneon (VeloNeon_note deposu, linux-desktop dalı). Flutter: /opt/flutter
export PATH=/opt/flutter/bin:$PATH PUB_CACHE=/opt/pub-cache
cp -r /veloneon/flutter_application_1 "$WORK/app"
cd "$WORK/app"
flutter --suppress-analytics config --no-analytics >/dev/null 2>&1 || true
flutter pub get >/dev/null
flutter build linux --release >/dev/null
B=build/linux/x64/release/bundle
mkdir -p "$DEST/opt/veloneon-notes" "$DEST/usr/bin"
cp -r $B/* "$DEST/opt/veloneon-notes/"
BIN=$(find "$DEST/opt/veloneon-notes" -maxdepth 1 -type f -perm -u+x | head -1)
ln -s "/opt/veloneon-notes/$(basename "$BIN")" "$DEST/usr/bin/veloneon-notes"
install -Dm644 "$ROOT/packaging/veloneon-notes/net.yazify.VeloneonNotes.desktop" "$DEST/usr/share/applications/net.yazify.VeloneonNotes.desktop"
ICON=$(ls assets/*icon*.png assets/images/*icon*.png 2>/dev/null | head -1)
[ -n "$ICON" ] && install -Dm644 "$ICON" "$DEST/usr/share/icons/hicolor/512x512/apps/veloneon-notes.png"
