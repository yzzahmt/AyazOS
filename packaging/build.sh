#!/bin/bash
# Bir AyazOS paketini derler: packaging/<ad>/{control,stage.sh,postinst,...}
# Kullanım: build.sh <paket> <çıktı-dizini>
# Mimariye bağlı paketler amd64 derleme kökünde (chroot) çalıştırılmalıdır.
set -euo pipefail
PKG=$1; OUT=${2:-/srv/out}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
VERSION=$(cat "$ROOT/VERSION")
SRC="$HERE/$PKG"
WORK=$(mktemp -d)
DEST="$WORK/root"
mkdir -p "$DEST/DEBIAN" "$OUT"
export DEST ROOT VERSION SRC WORK
bash "$SRC/stage.sh"

ARCH=all
if find "$DEST" -type f \( -name '*.so' -o -perm -u+x \) -exec file {} + 2>/dev/null | grep -q ELF; then
  ARCH=$(dpkg --print-architecture)
  # Paylaşımlı kütüphane bağımlılıklarını hesapla
  mkdir -p "$WORK/debian"; : > "$WORK/debian/control"
  printf 'Source: %s\n\nPackage: %s\nArchitecture: any\n' "$PKG" "$PKG" > "$WORK/debian/control"
  ELFS=$(find "$DEST" -type f -exec file {} + | grep ELF | cut -d: -f1)
  SHLIBS=$(cd "$WORK" && dpkg-shlibdeps -O -l"$DEST/usr/lib" $ELFS 2>/dev/null | sed -n 's/^shlibs:Depends=//p')
else
  SHLIBS=""
fi
DEPS=$(cat "$SRC/depends" "$WORK/extra-depends" 2>/dev/null | grep -v '^#' | grep -v '^$' | sort -u | tr '\n' ',' | sed 's/,$//; s/,,*/,/g')
ALL=$(echo "$SHLIBS,$DEPS" | sed 's/^,//; s/,$//; s/,/, /g')
SIZE=$(du -sk "$DEST" | cut -f1)
sed -e "s/@VERSION@/$VERSION/" -e "s/@ARCH@/$ARCH/" -e "s/@SIZE@/$SIZE/" "$SRC/control" > "$DEST/DEBIAN/control"
[ -n "$ALL" ] && echo "Depends: $ALL" >> "$DEST/DEBIAN/control"
for f in postinst prerm postrm preinst conffiles triggers; do
  [ -f "$SRC/$f" ] && install -m755 "$SRC/$f" "$DEST/DEBIAN/$f"
done
[ -f "$DEST/DEBIAN/conffiles" ] && chmod 644 "$DEST/DEBIAN/conffiles"
dpkg-deb --root-owner-group -Zzstd -b "$DEST" "$OUT/${PKG}_${VERSION}_${ARCH}.deb" >/dev/null
echo "$OUT/${PKG}_${VERSION}_${ARCH}.deb"
rm -rf "$WORK"
