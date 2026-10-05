#!/bin/bash
# Optional lidr add-on: reset the internal keyboard controller when the lid is
# opened after lidr kept the laptop awake. Run from a terminal (needs sudo).
#
#   keyboard-fix/install.sh              install / update
#   keyboard-fix/install.sh --uninstall  remove everything it installed
#
# Installs:
#   /usr/local/bin/i8042-reset                root helper (unbind/bind i8042)
#   /etc/sudoers.d/lidr-i8042-reset           NOPASSWD rule for that helper only
#   ~/.local/bin/lidr-lid-open                Hyprland lid-open handler
#   a marked "lidr keyboard fix" block in ~/.config/hypr/bindings.lua

set -eu

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HELPER=/usr/local/bin/i8042-reset
SUDOERS=/etc/sudoers.d/lidr-i8042-reset
HANDLER="$HOME/.local/bin/lidr-lid-open"
BINDINGS="$HOME/.config/hypr/bindings.lua"
BEGIN="-- >>> lidr keyboard fix >>>"
END="-- <<< lidr keyboard fix <<<"

remove_block() {
  [[ -f $BINDINGS ]] || return 0
  grep -qxF -- "$BEGIN" "$BINDINGS" || return 0
  sed -i "/^-- >>> lidr keyboard fix >>>\$/,/^-- <<< lidr keyboard fix <<<\$/d" "$BINDINGS"
  # Drop the blank separator line the block was appended after.
  sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$BINDINGS"
}

reload_hyprland() {
  command -v hyprctl >/dev/null || return 0
  hyprctl reload >/dev/null
  local errors
  errors=$(hyprctl configerrors)
  if [[ -n ${errors//[[:space:]]/} ]]; then
    echo "Hyprland config errors:" >&2
    echo "$errors" >&2
    return 1
  fi
}

uninstall() {
  remove_block
  rm -f "$HANDLER"
  sudo rm -f "$SUDOERS" "$HELPER"
  reload_hyprland
  echo "lidr keyboard fix removed (Omarchy's default lid-open binding is back)."
}

install() {
  [[ -f $BINDINGS ]] || { echo "No $BINDINGS; is this Omarchy?" >&2; exit 1; }

  sudo install -m 755 -o root -g root "$HERE/i8042-reset" "$HELPER"
  local rule tmp
  rule="$(id -un) ALL=(root) NOPASSWD: $HELPER"
  tmp=$(mktemp)
  echo "$rule" >"$tmp"
  sudo visudo -cqf "$tmp"
  sudo install -m 440 -o root -g root "$tmp" "$SUDOERS"
  rm -f "$tmp"

  install -D -m 755 "$HERE/lid-open.sh" "$HANDLER"

  remove_block
  cat >>"$BINDINGS" <<LUA

$BEGIN
-- Added by lidr (keyboard-fix/install.sh); remove with
-- keyboard-fix/install.sh --uninstall. Replaces Omarchy's default lid-open
-- binding with one that also resets the keyboard controller when lidr kept
-- the laptop awake with the lid closed.
hl.unbind("switch:off:Lid Switch")
o.bind("switch:off:Lid Switch", nil, os.getenv("HOME") .. "/.local/bin/lidr-lid-open", { locked = true })
$END
LUA

  reload_hyprland
  echo "lidr keyboard fix installed. Log: \${XDG_STATE_HOME:-~/.local/state}/lidr/lid-open.log"
}

case "${1:-}" in
"") install ;;
--uninstall) uninstall ;;
*) echo "Usage: $0 [--uninstall]" >&2; exit 2 ;;
esac
