#!/bin/bash
# Usage: vm-run.sh <script.py|script.sh> [args]  -- copies branding/tools to the VM (~/brand), runs the script there,
# then copies ~/brand/out/ back into branding/ (wallpapers, logo, plymouth).
. /Volumes/HDD/Projeler/Projeler/AyazOS/scripts/env.sh
R=/Volumes/HDD/Projeler/Projeler/AyazOS
SSHO="-F /dev/null -i $HOME/.ssh/id_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -P 2222"
$R/scripts/vssh 'mkdir -p ~/brand/tools ~/brand/out'
scp $SSHO -q -r $R/branding/tools/* ayaz@127.0.0.1:brand/tools/ || exit 1
$R/scripts/vssh "mkdir -p ~/brand/logo-src"; scp $SSHO -q $R/branding/logo/*.svg ayaz@127.0.0.1:brand/logo-src/
S=$1; shift
case $S in *.py) CMD="python3";; *) CMD="bash";; esac
$R/scripts/vssh "cd ~/brand/tools && SCALE=${SCALE:-1.0} $CMD $S $*" || exit 1
