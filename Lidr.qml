import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Bar toggle that keeps the laptop running while the lid is closed.
// See lidr.sh for how the actual inhibitor lock is held.
BarWidget {
  id: root
  moduleName: "lidr"

  property bool stayingAwake: false

  // Resolves next to this file regardless of what directory name the plugin
  // is installed under.
  readonly property string scriptPath: {
    var url = Qt.resolvedUrl("lidr.sh").toString()
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.slice(7)) : url
  }

  // Same collapse/reveal behavior as the built-in indicators (Stay Awake,
  // Dictation, Reminder, ...): hidden while off, peeking (dimmed) while the
  // pointer is anywhere over the bar's center section, and always shown once
  // enabled. centerSectionRevealHeld is set by hovering the whole center
  // section, not just this widget, so it stays consistent with those.
  readonly property bool revealed: root.stayingAwake
    || (root.bar && root.bar.centerSectionRevealHeld === true)

  visible: true
  implicitWidth: reveal.implicitWidth
  implicitHeight: reveal.implicitHeight

  function refresh() {
    if (statusProc.running) return
    statusProc.command = ["bash", root.scriptPath, "--status"]
    statusProc.running = true
  }

  function toggle() {
    if (toggleProc.running) return
    toggleProc.command = ["bash", root.scriptPath, "--toggle"]
    toggleProc.running = true
  }

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    onExited: function(exitCode) { root.stayingAwake = exitCode === 0 }
  }

  Process {
    id: toggleProc
    onExited: function() { root.refresh() }
  }

  // Catches the lock being released some other way (e.g. the held process
  // was killed outside this widget), so the icon doesn't go stale.
  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "lidr"

    function status(): string {
      return JSON.stringify({ active: root.stayingAwake })
    }

    function toggle(): string {
      root.toggle()
      return root.stayingAwake ? "disabled" : "enabled"
    }

    function refresh(): void {
      root.refresh()
    }
  }

  Item {
    id: reveal

    implicitWidth: root.vertical ? button.implicitWidth : (root.revealed ? button.implicitWidth : 0)
    implicitHeight: root.vertical ? (root.revealed ? button.implicitHeight : 0) : button.implicitHeight
    clip: true

    BarIconButton {
      id: button
      anchors.centerIn: parent
      bar: root.bar
      text: "󰌢"
      active: root.stayingAwake
      dimmed: !root.stayingAwake
      // Matches the built-in indicators (Stay Awake, Dictation, ...): "lit"
      // is just full-opacity theme foreground, not an accent/urgent tint.
      useActiveColor: false
      tooltipText: root.stayingAwake
        ? "Allow lid close to suspend the laptop"
        : "Keep the laptop running with the lid closed"
      onPressed: root.toggle()
    }
  }
}
