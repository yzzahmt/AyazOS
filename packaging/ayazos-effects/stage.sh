set -e
cp -r "$ROOT/compositor/ayaz-effects" "$WORK/fx"; rm -rf "$WORK/fx/build"
cd "$WORK/fx"; meson setup build --prefix=/usr >/dev/null; ninja -C build >/dev/null
DESTDIR="$DEST" ninja -C build install >/dev/null
