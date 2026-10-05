# Lidr

![Lidr bar states: off, off while hovered, and on](screenshots/states.png)

An [Omarchy](https://omarchy.org/) shell plugin that adds a bar toggle for
keeping your laptop running while the lid is closed — useful for things like
long-running builds, downloads, or a headless SSH session you don't want to
interrupt just because you closed the lid to carry the laptop somewhere.

Behaves just like Omarchy's built-in indicators (Stay Awake, Dictation, ...):

- **Off**: hidden — no icon, no wasted bar space.
- **Off, hovering the bar's center section**: peeks into view, dimmed, so
  you can find and click it.
- **On**: always shown, lit — closing the lid will *not* suspend the machine.

The screen still turns off and locks when you close the lid (that's Omarchy's
normal lid-close handling, unrelated to this toggle) — the machine just keeps
running underneath, so anything you had going (downloads, builds, a remote
session) keeps making progress.

## Install

```
omarchy plugin add https://github.com/jsprada/lidr.git --enable
```

Or clone manually and enable it yourself:

```
git clone https://github.com/jsprada/lidr.git ~/.config/omarchy/plugins/lidr
omarchy plugin enable lidr
```

## How it works

Enabling the toggle starts a transient systemd user unit, `lidr.service`,
that runs

```
systemd-inhibit --what=handle-lid-switch:sleep --mode=block sleep infinity
```

That's a real logind inhibitor lock: it blocks suspend outright (`sleep`) and
also tells logind not to run its own automatic lid-close handling
(`handle-lid-switch`), so it holds regardless of which path would otherwise
trigger a suspend. Because the unit belongs to your systemd user manager
rather than to the shell, it survives Quickshell/omarchy-shell restarts.
Disabling the toggle stops the unit, which releases the lock. Everything is
addressed by unit name, so there is no PID file to go stale.

The bar widget itself (`Lidr.qml`) just polls `lidr.sh --status`
and calls `lidr.sh --toggle` on click — all state lives in that one
script, so nothing needs a background service.

It's also scriptable over Omarchy's shell IPC:

```
omarchy-shell lidr status
omarchy-shell lidr toggle
```

## Optional: keyboard fix for lid close without suspend

On some laptops (seen on a ThinkPad), closing the lid *without* suspending
can leave the internal keyboard dead after you open it again. The touchpad
still works, but the kernel stops receiving keystrokes until the i8042
keyboard controller is reset or the machine reboots. A normal suspend/resume
resets the controller, so this only happens while Lidr is on.

To reset the controller automatically on lid open while Lidr is on, run
this once from a terminal (it asks for sudo):

```
~/.config/omarchy/plugins/lidr/keyboard-fix/install.sh
```

It installs:

- `/usr/local/bin/i8042-reset`: unbinds and rebinds the i8042 driver.
- `/etc/sudoers.d/lidr-i8042-reset`: a passwordless sudo rule for that
  helper only.
- `~/.local/bin/lidr-lid-open`: runs Omarchy's normal lid-open handler,
  then resets the keyboard if `lidr.service` is active.
- A block in `~/.config/hypr/bindings.lua`, between
  `-- >>> lidr keyboard fix >>>` markers, that points
  `switch:off:Lid Switch` at the handler.

The keyboard is unavailable for about 3 seconds after each lid open while
Lidr is on. Each reset is logged to `~/.local/state/lidr/lid-open.log`.

Remove it with `keyboard-fix/install.sh --uninstall`. Removing the plugin
does **not** remove the fix, so uninstall the fix first.

## Uninstall

```
~/.config/omarchy/plugins/lidr/keyboard-fix/install.sh --uninstall  # if installed
omarchy plugin remove lidr
```
