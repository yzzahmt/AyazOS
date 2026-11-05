#!/bin/bash
# Tam derleme: paketler -> imzalı depo -> ISO. Derleme VM'inde çalıştırılır.
#   distro/build-all.sh [--skip-debs]
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd "$HERE/.." && pwd)
VER=$(cat "$ROOT/VERSION")
if [ "${1:-}" != "--skip-debs" ]; then
  sudo "$HERE/build-debs.sh"
fi
rm -rf /srv/repo.new; sudo mkdir -p /srv/repo.new; sudo chown "$(id -u)" /srv/repo.new
"$ROOT/repo/publish.sh" /srv/debs /srv/repo.new
sudo rm -rf /srv/repo; sudo mv /srv/repo.new /srv/repo
sudo "$HERE/build-iso.sh" /srv/repo "/srv/ayazos-$VER-amd64.iso"
ls -la "/srv/ayazos-$VER-amd64.iso"
