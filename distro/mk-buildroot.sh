#!/bin/bash
# amd64 paket derleme kökü (VM içinde, qemu-user ile). /srv/build-amd64
set -euo pipefail
R=/srv/build-amd64
M=http://archive.ubuntu.com/ubuntu
if [ ! -x $R/usr/bin/apt-get ]; then
  sudo debootstrap --arch=amd64 --variant=buildd --components=main,universe resolute $R $M
fi
echo "deb $M resolute main universe restricted multiverse
deb $M resolute-updates main universe restricted multiverse
deb http://security.ubuntu.com/ubuntu resolute-security main universe restricted multiverse" | sudo tee $R/etc/apt/sources.list >/dev/null
sudo rm -f $R/etc/apt/sources.list.d/ubuntu.sources
for d in proc sys dev dev/pts; do mountpoint -q $R/$d || sudo mount --bind /$d $R/$d; done
sudo cp /etc/resolv.conf $R/etc/resolv.conf
sudo chroot $R bash -c 'export DEBIAN_FRONTEND=noninteractive; apt-get update -q >/dev/null && apt-get install -y -q --no-install-recommends \
  build-essential git cmake ninja-build pkg-config meson debhelper devscripts fakeroot dpkg-dev ca-certificates \
  qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev qt6-shadertools-dev qt6-wayland-dev qt6-wayland-private-dev qt6-svg-dev \
  libwayland-dev wayland-protocols libpipewire-0.3-dev libpam0g-dev libdrm-dev libgbm-dev libcli11-dev libjemalloc-dev spirv-tools libxcb1-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev libglib2.0-dev libunwind-dev libdbus-1-dev \
  wayfire-dev libwf-config-dev libwlroots-0.19-dev libglm-dev libegl-dev libgles-dev libinput-dev libxkbcommon-dev libcairo2-dev libpango1.0-dev nlohmann-json3-dev libboost-dev libevdev-dev libglibmm-2.4-dev >/dev/null; echo chroot-ok'
