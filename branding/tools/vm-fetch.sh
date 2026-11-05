#!/bin/bash
# Usage: vm-fetch.sh <relative path under ~/brand/out> -> branding/<same path>
. /Volumes/HDD/Projeler/Projeler/AyazOS/scripts/env.sh
R=/Volumes/HDD/Projeler/Projeler/AyazOS
SSHO="-F /dev/null -i $HOME/.ssh/id_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -P 2222"
mkdir -p "$R/branding/$(dirname $1)"
scp $SSHO -q -r "ayaz@127.0.0.1:brand/out/$1" "$R/branding/$(dirname $1)/"
