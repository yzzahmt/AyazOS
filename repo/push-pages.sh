#!/bin/bash
# APT deposunu GitHub Pages'e (gh-pages dalı, /apt) gönderir.
# Kullanım: push-pages.sh <reprepro çıktı dizini>
# Pages ayarı bir kez açılmalı: Settings > Pages > Branch: gh-pages / root
set -euo pipefail
SRC=$(realpath "$1")
HERE=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d)
git -C "$HERE" worktree add -q --orphan -B gh-pages "$W" 2>/dev/null || git -C "$HERE" worktree add -q "$W" gh-pages
cd "$W"
rm -rf apt && mkdir -p apt
cp -r "$SRC/dists" "$SRC/pool" apt/
cp "$SRC/ayazos-archive-keyring.gpg" apt/
touch .nojekyll
printf '<!doctype html><meta charset="utf-8"><title>AyazOS APT</title><p>AyazOS paket deposu.</p>\n' > index.html
git add -A
git commit -qm "Update package repository" || true
git push -q origin gh-pages
cd "$HERE"; git worktree remove --force "$W"
