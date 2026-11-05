#!/bin/bash
# AyazOS APT deposunu oluşturur/günceller (VM içinde çalışır).
# Kullanım: publish.sh <deb dizini> <depo çıktı dizini>
set -euo pipefail
DEBS=$1; OUT=$2
KEYID=$(gpg --list-secret-keys --with-colons "AyazOS Archive" 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')
if [ -z "$KEYID" ]; then
  gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key "AyazOS Archive <yazahmet772@hotmail.com>" ed25519 sign 5y
  KEYID=$(gpg --list-secret-keys --with-colons "AyazOS Archive" | awk -F: '/^fpr/ {print $10; exit}')
fi
mkdir -p "$OUT/conf"
cat > "$OUT/conf/distributions" <<CONF
Origin: AyazOS
Label: AyazOS
Suite: resolute
Codename: resolute
Architectures: amd64
Components: main
Description: AyazOS packages
SignWith: $KEYID
CONF
for d in "$DEBS"/*.deb; do reprepro -b "$OUT" includedeb resolute "$d" >/dev/null; done
gpg --export "$KEYID" > "$OUT/ayazos-archive-keyring.gpg"
reprepro -b "$OUT" list resolute
