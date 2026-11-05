set -e
B="$ROOT/branding"
mkdir -p "$DEST/usr/share/backgrounds/ayazos" "$DEST/usr/share/pixmaps" "$DEST/usr/share/plymouth/themes" "$DEST/usr/share/ayazos"
cp "$B"/wallpapers/*.jpg "$DEST/usr/share/backgrounds/ayazos/" 2>/dev/null || true
cp "$B/logo/ayazos-mark.svg" "$DEST/usr/share/pixmaps/ayazos.svg"
[ -f "$B/logo/png/ayazos-mark-256.png" ] && cp "$B/logo/png/ayazos-mark-256.png" "$DEST/usr/share/pixmaps/ayazos.png"
for s in 16 32 48 64 128 256 512; do
  f=$(ls "$B"/logo/png/*$s*.png 2>/dev/null | grep -v tile | head -1)
  [ -n "$f" ] && install -Dm644 "$f" "$DEST/usr/share/icons/hicolor/${s}x${s}/apps/ayazos.png"
done
install -Dm644 "$B/logo/ayazos-mark.svg" "$DEST/usr/share/icons/hicolor/scalable/apps/ayazos.svg"
[ -d "$B/plymouth/ayazos" ] && cp -r "$B/plymouth/ayazos" "$DEST/usr/share/plymouth/themes/ayazos"
install -Dm644 "$ROOT/distro/os-release" "$DEST/usr/share/ayazos/os-release"
find "$DEST" -name '.DS_Store' -delete
