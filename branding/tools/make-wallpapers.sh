#!/bin/bash
# Regenerates every wallpaper (run inside the VM from ~/brand/tools). Takes roughly 6-10 minutes.
set -e
cd "$(dirname "$0")"
for s in default blackhole nebula planet milkyway aurora crystal water comet; do
  echo "== wp_$s"; python3 wp_$s.py
done
python3 wp_derive.py
