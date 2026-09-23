#!/bin/bash

# Toggle whether the laptop keeps running when the lid is closed.
#
# Implemented as a systemd-logind inhibitor lock, held by a detached
# `systemd-inhibit ... sleep infinity` process so it survives Quickshell
# restarts. The PID file holds the PID of that process, which (via setsid)
# is also its own process group leader, so killing the group cleanly stops
# both it and the lock it holds.
#
# Inhibits both handle-lid-switch (tells logind not to run its own lid-close
# action at all) and sleep (blocks suspend outright, however it gets
# triggered) so this holds regardless of which path would otherwise suspend
# the machine.

set -u

STATE_DIR="$HOME/.local/state/omarchy/toggles"
PID_FILE="$STATE_DIR/lidr.pid"
WHY="Keep the laptop running with the lid closed"

is_active() {
  [[ -f $PID_FILE ]] || return 1
  local pid
  pid=$(<"$PID_FILE")
  [[ $pid =~ ^[0-9]+$ ]] || return 1
  kill -0 "-$pid" 2>/dev/null
}

start() {
  mkdir -p "$STATE_DIR"
  setsid systemd-inhibit \
    --what=handle-lid-switch:sleep \
    --mode=block \
    --who="Lidr" \
    --why="$WHY" \
    sleep infinity >/dev/null 2>&1 &
  disown
  echo "$!" >"$PID_FILE"
}

stop() {
  if [[ -f $PID_FILE ]]; then
    local pid
    pid=$(<"$PID_FILE")
    [[ $pid =~ ^[0-9]+$ ]] && kill -TERM "-$pid" 2>/dev/null
  fi
  rm -f "$PID_FILE"
}

notify() {
  command -v omarchy-notification-send >/dev/null 2>&1 || return 0
  omarchy-notification-send -g "$1" "$2" >/dev/null 2>&1 || true
}

case "${1:-}" in
--status)
  is_active
  exit $?
  ;;
--toggle)
  if is_active; then
    stop
    notify 󰤄 "Lid close will suspend the laptop"
  else
    start
    notify 󰌢 "Laptop will stay awake with the lid closed"
  fi
  ;;
*)
  echo "Usage: $0 --status|--toggle" >&2
  exit 2
  ;;
esac
