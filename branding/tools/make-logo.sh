#!/bin/bash
# Renders logo PNGs (run inside the VM; sources are copied to ~/brand/logo-src by vm-run.sh)
set -e
S=~/brand/logo-src; O=~/brand/out/logo/png
mkdir -p $O
for n in 16 32 48 64 128 256 512 1024; do rsvg-convert -w $n -h $n $S/ayazos-mark.svg -o $O/ayazos-mark-$n.png; done
rsvg-convert -w 512 -h 512 $S/ayazos-tile.svg -o $O/ayazos-tile-512.png
for n in 64 128 256 1024; do rsvg-convert -w $n -h $n $S/ayazos-tile.svg -o $O/ayazos-tile-$n.png; done
rsvg-convert -h 360 $S/ayazos-wordmark.svg -o $O/ayazos-wordmark.png
rsvg-convert -h 720 $S/ayazos-wordmark.svg -o $O/ayazos-wordmark@2x.png
ls -la $O
convert $O/ayazos-wordmark.png -background '#0A0E15' -flatten $O/ayazos-wordmark-on-dark.png
