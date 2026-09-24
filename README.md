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

## Uninstall

```
omarchy plugin remove lidr
```
