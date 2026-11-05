set -e
QV=v0.3.2
cd "$WORK"; git clone -q --depth 1 -b $QV https://github.com/quickshell-mirror/quickshell.git qs
cmake -S qs -B qs/build -GNinja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr \
  -DCRASH_HANDLER=OFF -DHYPRLAND=OFF -DI3=OFF -DX11=OFF -DSERVICE_GREETD=ON -DDISTRIBUTOR="AyazOS" >/dev/null
ninja -C qs/build >/dev/null
DESTDIR="$DEST" ninja -C qs/build install >/dev/null
