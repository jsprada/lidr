#!/bin/bash
# Part of lidr's optional keyboard fix (see keyboard-fix/install.sh).
# Installed as ~/.local/bin/lidr-lid-open and bound to Hyprland's
# switch:off:Lid Switch in place of Omarchy's default lid-open binding.
#
# Runs Omarchy's stock lid-open handler, then, if lidr kept the laptop awake
# while the lid was closed, resets the i8042 keyboard controller. On some
# laptops a lid close WITHOUT suspend can leave the internal keyboard dead
# (IRQ1 stops firing entirely); a real suspend/resume re-initialises the
# controller, so the reset is only needed while lidr holds its inhibitor.

omarchy-hyprland-monitor-clamshell

systemctl --user --quiet is-active lidr.service || exit 0

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/lidr/lid-open.log"
mkdir -p "${LOG%/*}"
irq() { awk '$NF == "i8042" && $1 == "1:" { s = 0; for (i = 2; i < NF - 2; i++) s += $i; print s }' /proc/interrupts; }

echo "$(date -Is) lid opened with lidr active, IRQ1=$(irq); resetting i8042" >>"$LOG"
if sudo -n /usr/local/bin/i8042-reset >>"$LOG" 2>&1; then
  echo "$(date -Is) reset done, IRQ1=$(irq)" >>"$LOG"
else
  echo "$(date -Is) reset FAILED (exit $?)" >>"$LOG"
  omarchy-notification-send -u critical "Lidr: keyboard reset failed" "See $LOG" >/dev/null 2>&1
fi
