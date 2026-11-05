#!/bin/bash
# Tüm AyazOS paketlerini amd64 için derler (VM içinde, sudo ile).
# Kullanım: sudo build-debs.sh [paket ...]   çıktı: /srv/debs
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd "$HERE/.." && pwd)
B=/srv/build-amd64; OUT=/srv/debs
mkdir -p $OUT $B/src $B/out
for d in proc sys dev dev/pts; do mountpoint -q $B/$d || mount --bind /$d $B/$d; done
mountpoint -q $B/src || mount --bind "$ROOT" $B/src
cp /etc/resolv.conf $B/etc/resolv.conf
PKGS=${*:-quickshell ayazos-wayfire-extra ayazos-effects ayazos-apps ayazos-shell ayazos-session ayazos-branding ayazos-update ayazos-desktop}
for p in $PKGS; do
  echo "== $p"
  chroot $B /usr/bin/env -i HOME=/root PATH=/usr/sbin:/usr/bin:/sbin:/bin LC_ALL=C.UTF-8 bash /src/packaging/build.sh "$p" /out
done
cp $B/out/*.deb $OUT/
ls -la $OUT
