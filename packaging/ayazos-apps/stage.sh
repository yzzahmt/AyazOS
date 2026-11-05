set -e
cp -r "$ROOT/apps/host" "$WORK/host"; rm -rf "$WORK/host/build"
cmake -S "$WORK/host" -B "$WORK/host/build" -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr >/dev/null
ninja -C "$WORK/host/build" >/dev/null
DESTDIR="$DEST" ninja -C "$WORK/host/build" install >/dev/null
# Ortak QML modülü: AyazOS.UI (kabukla aynı tasarım bileşenleri)
U="$DEST/usr/share/ayazos/qml/AyazOS/UI"
mkdir -p "$U/services" "$U/components" "$U/assets"
cp "$ROOT/shell/services/Theme.qml" "$U/services/"
printf 'singleton Theme 1.0 Theme.qml\n' > "$U/services/qmldir"
cp "$ROOT"/shell/components/*.qml "$U/components/"
cp "$ROOT/shell/components/qmldir" "$U/components/"
cp -r "$ROOT/shell/assets/icons" "$U/assets/icons"
printf 'module AyazOS.UI\nsingleton Theme 1.0 services/Theme.qml\nGlass 1.0 components/Glass.qml\nIcon 1.0 components/Icon.qml\nIconButton 1.0 components/IconButton.qml\n' > "$U/qmldir"
# Uygulamalar
for app in "$ROOT"/apps/*/; do
  name=$(basename "$app"); [ "$name" = host ] && continue
  mkdir -p "$DEST/usr/share/ayazos/apps/$name"
  cp -r "$app"/* "$DEST/usr/share/ayazos/apps/$name/"
  [ -f "$app/ayaz-$name.desktop" ] && install -Dm644 "$app/ayaz-$name.desktop" "$DEST/usr/share/applications/ayaz-$name.desktop"
  printf '#!/bin/sh\nexec ayaz-app %s "$@"\n' "$name" > "$DEST/usr/bin/ayaz-$name"; chmod 755 "$DEST/usr/bin/ayaz-$name"
done
cat "$ROOT"/apps/*/DEPENDS 2>/dev/null >> "$WORK/extra-depends" || true
find "$DEST" -name '.DS_Store' -delete
find "$DEST" -name DEPENDS -delete
