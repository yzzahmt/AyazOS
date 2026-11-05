#!/bin/bash
# Sanal makinede AyazOS oturumunu başlatır (test için). Kullanım: vm-session.sh start|stop|shot <ad>
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export LIBSEAT_BACKEND=seatd WLR_RENDERER_ALLOW_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1
export XDG_CURRENT_DESKTOP=AyazOS XDG_SESSION_TYPE=wayland QT_QPA_PLATFORM=wayland
case "${1:-start}" in
  start)
    pkill -x wayfire; pkill -x qs; sleep 1
    mkdir -p ~/.config/quickshell; ln -sfn ~/AyazOS/shell ~/.config/quickshell/ayazos
    nohup wayfire -c ~/AyazOS/session/wayfire.ini > /tmp/wayfire.log 2>&1 &
    for i in $(seq 1 30); do ls $XDG_RUNTIME_DIR/wayland-* >/dev/null 2>&1 && break; sleep 1; done
    echo "wayland: $(ls $XDG_RUNTIME_DIR | grep -E '^wayland-[0-9]+$' | head -1)";;
  stop) pkill -x qs; pkill -x wayfire;;
  shot)
    export WAYLAND_DISPLAY=$(ls $XDG_RUNTIME_DIR | grep -E '^wayland-[0-9]+$' | head -1)
    grim -t png ~/shots/${2:-shot}.png && echo ~/shots/${2:-shot}.png;;
  run)
    export WAYLAND_DISPLAY=$(ls $XDG_RUNTIME_DIR | grep -E '^wayland-[0-9]+$' | head -1)
    shift; "$@";;
esac
