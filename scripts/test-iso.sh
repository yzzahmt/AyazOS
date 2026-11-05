#!/bin/bash
# AyazOS ISO'sunu x86_64 sanal makinede (UEFI) başlatır. Emülasyon (TCG) olduğu için yavaştır;
# işlevsellik testi içindir, performans ölçümü değildir.
#   test-iso.sh boot <iso>      canlı oturumu başlat (40 GB boş disk ekli)
#   test-iso.sh disk            kurulu diskten başlat
#   test-iso.sh shot <ad>       ekran görüntüsü (.tc/shots/<ad>.png)
#   test-iso.sh key <tuşlar>    QEMU sendkey (ör. ret, ctrl-alt-t)
#   test-iso.sh stop
. /Volumes/HDD/Projeler/Projeler/AyazOS/scripts/env.sh
V=$AYAZ_ROOT/vm; MON=$V/x86-mon.sock
mon() { python3 - "$MON" "$1" <<'PY'
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.2); s.recv(4096)
s.send((sys.argv[2] + "\n").encode()); time.sleep(0.8); print(s.recv(65536).decode(errors="ignore").strip().splitlines()[-1:])
PY
}
start() {
  [ -f $V/x86.qcow2 ] || qemu-img create -q -f qcow2 $V/x86.qcow2 40G
  [ -f $V/x86-vars.fd ] || cp $TC/prefix/share/qemu/edk2-i386-vars.fd $V/x86-vars.fd
  qemu-system-x86_64 -machine q35 -accel tcg,thread=multi,tb-size=1024 -cpu max -smp 6 -m 6144 \
    -drive if=pflash,format=raw,readonly=on,file=$TC/prefix/share/qemu/edk2-x86_64-code.fd \
    -drive if=pflash,format=raw,file=$V/x86-vars.fd \
    -drive if=virtio,format=qcow2,file=$V/x86.qcow2,cache=writeback,discard=unmap \
    "$@" \
    -device virtio-vga -display none -vnc 127.0.0.1:2 \
    -device virtio-net-pci,netdev=n0 -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2223-:22 \
    -device qemu-xhci -device usb-kbd -device usb-tablet \
    -monitor unix:$MON,server,nowait -serial file:$V/x86-serial.log \
    -daemonize -pidfile $V/x86.pid
}
case "$1" in
  boot) start -drive media=cdrom,file="$2",readonly=on -boot order=d ;;
  disk) start -boot order=c ;;
  shot) mon "screendump $TC/shots/$2.png -f png" >/dev/null; echo "$TC/shots/$2.png" ;;
  key)  shift; for k in "$@"; do mon "sendkey $k" >/dev/null; done ;;
  type) mon "$(python3 -c 'import sys; m={" ":"spc",".":"dot","-":"minus","/":"slash"}; print("\n".join("sendkey "+(m.get(c) or ("shift-"+c.lower() if c.isupper() else c)) for c in sys.argv[1]))' "$2" | head -1)" >/dev/null
        python3 -c 'import sys; m={" ":"spc",".":"dot","-":"minus","/":"slash"}; print("\n".join("sendkey "+(m.get(c) or ("shift-"+c.lower() if c.isupper() else c)) for c in sys.argv[1]))' "$2" | tail -n +2 | while read -r cmd; do mon "$cmd" >/dev/null; done ;;
  stop) [ -f $V/x86.pid ] && kill $(cat $V/x86.pid) 2>/dev/null; rm -f $V/x86.pid ;;
esac
