set -e
install -Dm755 "$ROOT/tools/ayaz-drivers" "$DEST/usr/libexec/ayaz-drivers"
install -Dm644 "$ROOT/tools/ayazos-drivers.service" "$DEST/usr/lib/systemd/system/ayazos-drivers.service"
# Yeni ekran kartı takılınca algılamayı yeniden çalıştır
mkdir -p "$DEST/usr/lib/udev/rules.d"
echo 'ACTION=="add", SUBSYSTEM=="pci", ATTR{class}=="0x03*", RUN+="/bin/rm -f /var/lib/ayazos/drivers.done"' > "$DEST/usr/lib/udev/rules.d/90-ayazos-drivers.rules"
