#!/bin/bash
# AyazOS canlı/kurulum ISO'su (amd64). Derleme VM'inde root olarak çalışır.
# Kullanım: sudo build-iso.sh <yerel depo dizini> <çıktı iso>
set -euo pipefail
REPO=$(realpath "$1"); ISO=$2
HERE=$(cd "$(dirname "$0")" && pwd); ROOT=$(cd "$HERE/.." && pwd)
W=/srv/iso; C=$W/chroot; I=$W/image
M=http://archive.ubuntu.com/ubuntu
VER=$(cat "$ROOT/VERSION")

log() { echo "[$(date +%H:%M:%S)] $*"; }
in_chroot() { chroot $C /usr/bin/env -i HOME=/root PATH=/usr/sbin:/usr/bin:/sbin:/bin DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8 bash -c "$*"; }
mounts() { for d in proc sys dev dev/pts run; do mkdir -p $C/$d; mountpoint -q $C/$d || mount --bind /$d $C/$d; done; mkdir -p $C/srv/repo; mountpoint -q $C/srv/repo || mount --bind "$REPO" $C/srv/repo; }
umounts() { for d in srv/repo run dev/pts dev sys proc; do mountpoint -q $C/$d && umount -l $C/$d || true; done; }
trap umounts EXIT

if [ ! -x $C/usr/bin/apt-get ]; then
  log "debootstrap"
  debootstrap --arch=amd64 --variant=minbase --components=main,universe,restricted,multiverse resolute $C $M >/dev/null
fi
mounts
cp /etc/resolv.conf $C/etc/resolv.conf 2>/dev/null || true
rm -f $C/etc/apt/sources.list.d/ubuntu.sources
cat > $C/etc/apt/sources.list.d/ubuntu.sources <<SRC
Types: deb
URIs: $M
Suites: resolute resolute-updates resolute-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu
Suites: resolute-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
SRC
# Derleme sırasında AyazOS paketleri yerel depodan gelir.
[ -d "$REPO/dists" ] && echo "deb [trusted=yes] file:/srv/repo resolute main" > $C/etc/apt/sources.list.d/ayazos-local.list
cp "$ROOT/repo/mozilla-keyring.asc" $C/usr/share/keyrings/packages.mozilla.org.asc
cp "$ROOT/repo/mozilla.sources" $C/etc/apt/sources.list.d/mozilla.sources
mkdir -p $C/etc/apt/preferences.d; cp "$ROOT/repo/apt-preferences" $C/etc/apt/preferences.d/ayazos
printf 'APT::Install-Recommends "false";\nAPT::Install-Suggests "false";\n' > $C/etc/apt/apt.conf.d/00ayazos-norecommends
echo ayazos > $C/etc/hostname
# initramfs ve servisleri chroot içinde başlatma
printf '#!/bin/sh\nexit 101\n' > $C/usr/sbin/policy-rc.d; chmod +x $C/usr/sbin/policy-rc.d

log "temel sistem"
in_chroot "dpkg --add-architecture i386"
in_chroot "apt-get update -q >/dev/null && apt-get install -y -q \
  linux-generic linux-firmware casper initramfs-tools systemd-sysv sudo locales tzdata keyboard-configuration console-setup \
  grub-efi-amd64-signed shim-signed grub-pc-bin grub-efi-amd64-bin efibootmgr os-prober \
  network-manager wpasupplicant iw ca-certificates curl \
  language-pack-tr language-pack-en hunspell-tr \
  calamares calamares-settings-ubuntu-common- squashfs-tools rsync \
  >/dev/null"
[ "${BASE_ONLY:-0}" = 1 ] && { log "temel sistem hazır (BASE_ONLY)"; exit 0; }
log "AyazOS masaüstü"
in_chroot "apt-get install -y -q ayazos-desktop >/dev/null"
in_chroot "apt-get purge -y -q snapd >/dev/null 2>&1 || true; apt-mark hold snapd >/dev/null 2>&1 || true"

log "yapılandırma"
in_chroot "locale-gen tr_TR.UTF-8 en_US.UTF-8 >/dev/null; update-locale LANG=tr_TR.UTF-8; ln -sf /usr/share/zoneinfo/Europe/Istanbul /etc/localtime"
printf 'XKBMODEL="pc105"\nXKBLAYOUT="tr"\nXKBVARIANT=""\nXKBOPTIONS=""\n' > $C/etc/default/keyboard
# Canlı oturum: kullanıcı ayazos, şifresiz otomatik giriş
printf 'export USERNAME="ayazos"\nexport USERFULLNAME="AyazOS Live"\nexport HOST="ayazos"\nexport BUILD_SYSTEM="Ubuntu"\nexport FLAVOUR="AyazOS"\n' > $C/etc/casper.conf
cat > $C/etc/greetd/config.toml <<'G'
[terminal]
vt = 1

[default_session]
command = "ayazos-greeter"
user = "greeter"

[initial_session]
command = "ayazos-session"
user = "ayazos"
G
# Kurulum aracı ve ayarları
rm -rf $C/etc/calamares; cp -r "$ROOT/distro/calamares" $C/etc/calamares
install -Dm644 "$ROOT/distro/calamares/install-ayazos.desktop" $C/usr/share/applications/install-ayazos.desktop
L=$(ls "$ROOT"/branding/logo/png/*256*.png 2>/dev/null | grep -v tile | head -1)
[ -n "$L" ] && cp "$L" $C/etc/calamares/branding/ayazos/logo.png
W=$(ls "$ROOT"/branding/logo/*wordmark*.png "$ROOT"/branding/logo/png/*wordmark*.png 2>/dev/null | head -1)
[ -n "$W" ] && cp "$W" $C/etc/calamares/branding/ayazos/welcome.png || cp $C/etc/calamares/branding/ayazos/logo.png $C/etc/calamares/branding/ayazos/welcome.png 2>/dev/null || true
# Canlı oturumda kurulum aracı dock'ta görünsün diye masaüstüne kısayol
mkdir -p $C/etc/skel/Masaüstü && cp "$ROOT/distro/calamares/install-ayazos.desktop" $C/etc/skel/Masaüstü/ 2>/dev/null || true
# GRUB görünümü
mkdir -p $C/etc/default/grub.d
cat > $C/etc/default/grub.d/ayazos.cfg <<'G'
GRUB_DISTRIBUTOR="AyazOS"
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 vt.global_cursor_default=0"
G
in_chroot "plymouth-set-default-theme ayazos 2>/dev/null || true; update-initramfs -u -k all >/dev/null 2>&1"
rm -f $C/usr/sbin/policy-rc.d $C/etc/apt/sources.list.d/ayazos-local.list
cp "$ROOT/repo/ayazos.sources" $C/etc/apt/sources.list.d/ayazos.sources
in_chroot "apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; : > /etc/machine-id"

log "imaj"
umounts; trap - EXIT
rm -rf $I; mkdir -p $I/casper $I/boot/grub $I/.disk
K=$(ls $C/boot/vmlinuz-* | sort -V | tail -1); R=$(ls $C/boot/initrd.img-* | sort -V | tail -1)
cp "$K" $I/casper/vmlinuz; cp "$R" $I/casper/initrd
chroot $C dpkg-query -W --showformat='${Package} ${Version}\n' > $I/casper/filesystem.manifest
du -sx --block-size=1 $C | cut -f1 > $I/casper/filesystem.size
mksquashfs $C $I/casper/filesystem.squashfs -comp zstd -Xcompression-level 19 -b 1M -noappend -e boot/efi -quiet
echo "AyazOS $VER amd64" > $I/.disk/info
touch $I/ayazos.disk
cat > $I/boot/grub/grub.cfg <<'G'
set default=0
set timeout=3
set timeout_style=menu
insmod all_video
insmod gfxterm
set gfxmode=auto
terminal_output gfxterm
set menu_color_normal=light-gray/black
set menu_color_highlight=white/blue
search --no-floppy --set=root --file /ayazos.disk
menuentry "AyazOS'u dene veya kur" {
    linux /casper/vmlinuz boot=casper quiet splash locale=tr_TR.UTF-8 keyboard-layouts=tr ---
    initrd /casper/initrd
}
menuentry "AyazOS (güvenli grafik)" {
    linux /casper/vmlinuz boot=casper nomodeset quiet splash locale=tr_TR.UTF-8 ---
    initrd /casper/initrd
}
G
log "iso"
B=/srv/build-amd64
chroot $B bash -c 'command -v grub-mkrescue >/dev/null && command -v xorriso >/dev/null && command -v mformat >/dev/null' || \
  chroot $B bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y -q grub-pc-bin grub-efi-amd64-bin grub-common xorriso mtools >/dev/null'
mkdir -p $B/srv/image; mount --bind $I $B/srv/image
for d in proc sys dev; do mountpoint -q $B/$d || mount --bind /$d $B/$d; done
chroot $B grub-mkrescue -o /srv/out.iso /srv/image -- -volid AYAZOS >/tmp/mkrescue.log 2>&1 || { umount $B/srv/image; tail -5 /tmp/mkrescue.log; exit 1; }
umount $B/srv/image
mv $B/srv/out.iso "$ISO"
ls -la "$ISO"
log "bitti"
