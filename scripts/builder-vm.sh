#!/bin/bash
# ARM64 derleme sanal makinesi (HVF hızlandırmalı). SSH: localhost:2222
. /Volumes/HDD/Projeler/Projeler/AyazOS/scripts/env.sh
cd $AYAZ_ROOT/vm
exec qemu-system-aarch64 -machine virt,highmem=on -accel hvf -cpu host -smp 6 -m 9216 \
  -drive if=pflash,format=raw,readonly=on,file=$TC/prefix/share/qemu/edk2-aarch64-code.fd \
  -drive if=pflash,format=raw,file=builder-vars.fd \
  -drive if=virtio,format=qcow2,file=builder.qcow2,cache=writeback,discard=unmap \
  -drive if=virtio,format=raw,file=seed.iso,readonly=on \
  -device virtio-net-pci,netdev=n0 -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-gpu-pci -device qemu-xhci -device usb-kbd -device usb-tablet \
  -vnc 127.0.0.1:1 -monitor unix:$AYAZ_ROOT/vm/builder-mon.sock,server,nowait \
  -serial file:$AYAZ_ROOT/vm/builder-serial.log -daemonize -pidfile $AYAZ_ROOT/vm/builder.pid
