set -e
install -Dm755 "$ROOT/tools/ayaz-exe" "$DEST/usr/bin/ayaz-exe"
install -Dm644 "$ROOT/tools/ayaz-exe.desktop" "$DEST/usr/share/applications/ayaz-exe.desktop"
