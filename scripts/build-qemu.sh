#!/bin/bash
# QEMU'yu kaynaktan HDD'ye derler. Homebrew kütüphaneleri yalnızca okunur.
set -euo pipefail
. /Volumes/HDD/Projeler/Projeler/AyazOS/scripts/env.sh
cd "$TC/src"
/opt/homebrew/bin/python3 -m venv "$TC/venv"
"$TC/venv/bin/pip" -q install meson ninja pkgconf tomli sphinx==8.2.3 sphinx-rtd-theme >/dev/null 2>&1 || "$TC/venv/bin/pip" -q install meson ninja pkgconf tomli
mkdir -p "$TC/prefix/bin"; ln -sf "$TC/venv/bin/pkgconf" "$TC/prefix/bin/pkg-config"
V=$(curl -s https://download.qemu.org/ | grep -oE 'qemu-[0-9]+\.[0-9]+\.[0-9]+\.tar\.xz' | sort -V | tail -1)
echo "QEMU=$V"
[ -f "$V" ] || curl -fsSLO "https://download.qemu.org/$V"
D=${V%.tar.xz}; [ -d "$D" ] || tar xf "$V"
[ -d libslirp ] || { curl -fsSL https://gitlab.freedesktop.org/slirp/libslirp/-/archive/v4.9.1/libslirp-v4.9.1.tar.gz | tar xz; mv libslirp-v4.9.1 libslirp; }
(cd libslirp && meson setup build --prefix="$TC/prefix" --libdir=lib --buildtype=release --wipe 2>/dev/null || meson setup build --prefix="$TC/prefix" --libdir=lib --buildtype=release; ninja -C build install)
cd "$D"; mkdir -p build; cd build
../configure --prefix="$TC/prefix" --target-list=x86_64-softmmu,aarch64-softmmu \
  --enable-slirp --enable-hvf --disable-docs --disable-cocoa --disable-sdl --disable-gtk --disable-vnc-sasl \
  --enable-vnc --disable-pvg --enable-tools --python="$TC/venv/bin/python3"
ninja -j6 install
"$TC/prefix/bin/qemu-system-x86_64" --version
echo BUILD_OK
