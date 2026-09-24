#!/bin/bash

# Toggle whether the laptop keeps running when the lid is closed.
#
# Implemented as a systemd-logind inhibitor lock, held by a
# `systemd-inhibit ... sleep infinity` process that runs as a transient
# systemd *user* unit (lidr.service). Because the unit belongs to the user
# manager rather than to Quickshell, it survives shell restarts, and because
# it is addressed by name, start/status/stop never touch a raw PID: there is
# no PID file to go stale and no risk of signalling an unrelated process
# whose PID happens to have been reused. Stopping the unit tears down its
# whole cgroup, which releases the lock.
#
# Inhibits both handle-lid-switch (tells logind not to run its own lid-close
# action at all) and sleep (blocks suspend outright, however it gets
# triggered) so this holds regardless of which path would otherwise suspend
# the machine.

set -u

UNIT="lidr.service"
WHY="Keep the laptop running with the lid closed"

# Left over from versions that tracked a detached process in a PID file.
LEGACY_PID_FILE="$HOME/.local/state/omarchy/toggles/lidr.pid"

is_active() {
  systemctl --user --quiet is-active "$UNIT"
}

start() {
  # A previous run that failed may still be loaded under this name; clear
  # it so systemd-run does not refuse to reuse the unit name.
  systemctl --user reset-failed "$UNIT" 2>/dev/null
  systemd-run --user --quiet --collect \
    --unit="${UNIT%.service}" \
    --description="$WHY" \
    systemd-inhibit \
    --what=handle-lid-switch:sleep \
    --mode=block \
    --who="Lidr" \
    --why="$WHY" \
    sleep infinity
}

stop() {
  systemctl --user stop "$UNIT" 2>/dev/null
}

# One-time migration: release an inhibitor started by an older version of
# this script. The PID is only signalled if the process it names is still
# a systemd-inhibit that we launched (checked via its command line) and is
# its own process group leader, as the old script arranged with setsid.
# Anything else means the PID went stale and was reused, so it is left
# alone and just the file is removed.
migrate_legacy() {
  [[ -f $LEGACY_PID_FILE ]] || return 0
  local pid cmdline pgid
  pid=$(<"$LEGACY_PID_FILE")
  rm -f "$LEGACY_PID_FILE"
  [[ $pid =~ ^[0-9]+$ ]] || return 0
  cmdline=$(tr '\0' '\n' 2>/dev/null <"/proc/$pid/cmdline") || return 0
  pgid=$(awk '{print $5}' 2>/dev/null "/proc/$pid/stat") || return 0
  [[ $pgid == "$pid" ]] || return 0
  grep -qx -- 'systemd-inhibit' <<<"$cmdline" || return 0
  grep -qx -- '--who=Lidr' <<<"$cmdline" || return 0
  kill -TERM "-$pid" 2>/dev/null
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
  migrate_legacy
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
