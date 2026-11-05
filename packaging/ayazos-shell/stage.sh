set -e
mkdir -p "$DEST/etc/xdg/quickshell"
cp -r "$ROOT/shell" "$DEST/etc/xdg/quickshell/ayazos"
find "$DEST/etc/xdg/quickshell/ayazos" -name '.DS_Store' -delete
