#!/bin/bash
# Sanal makinede AyazOS ana test oturumu (yalnızca kendi wayfire sürecini yönetir).
# Kullanım: vm-session.sh start|stop|shot <ad>|run <komut>
set -u
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export LIBSEAT_BACKEND=seatd WLR_RENDERER_ALLOW_SOFTWARE=1 WLR_NO_HARDWARE_CURSORS=1
export XDG_CURRENT_DESKTOP=AyazOS XDG_SESSION_TYPE=wayland QT_QPA_PLATFORM=wayland
PIDF=/tmp/ayaz-main.pid; SOCKF=/tmp/ayaz-main.sock
mine() { [ -f $PIDF ] && kill -0 "$(cat $PIDF)" 2>/dev/null; }
case "${1:-start}" in
  start)
    if mine; then kill "$(cat $PIDF)"; sleep 1; fi
    pkill -u "$(id -u)" -x qs; sleep 0.5
    mkdir -p ~/.config/quickshell; ln -sfn ~/AyazOS/shell ~/.config/quickshell/ayazos
    sed -e "s|^shell = .*|shell = qs -c ayazos|" -e "s|^idle = .*||" -e "s|^dpms_timeout = .*|dpms_timeout = -1|" ~/AyazOS/session/wayfire.ini > /tmp/wf-test.ini
    before=$(ls $XDG_RUNTIME_DIR | grep -E '^wayland-[0-9]+$' | sort)
    nohup wayfire -c /tmp/wf-test.ini > /tmp/wayfire.log 2>&1 &
    echo $! > $PIDF
    for i in $(seq 1 30); do
      now=$(ls $XDG_RUNTIME_DIR | grep -E '^wayland-[0-9]+$' | sort)
      new=$(comm -13 <(echo "$before") <(echo "$now") | head -1)
      [ -n "$new" ] && { echo "$new" > $SOCKF; break; }
      sleep 1
    done
    echo "wayland: $(cat $SOCKF)";;
  stop) mine && kill "$(cat $PIDF)";;
  shot)
    export WAYLAND_DISPLAY=$(cat $SOCKF)
    grim -t png ~/shots/${2:-shot}.png && echo ~/shots/${2:-shot}.png;;
  run)
    export WAYLAND_DISPLAY=$(cat $SOCKF)
    shift; "$@";;
esac
