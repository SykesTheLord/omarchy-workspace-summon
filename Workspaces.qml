import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.sykesthelord.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  // The output this bar surface is painted on. A bar exists per monitor, so
  // this is the display the click physically landed on — which is the whole
  // point here: the number you press names the workspace, the bar you press
  // it on names where that workspace should end up.
  function clickedMonitorName() {
    var window = root.QsWindow ? root.QsWindow.window : null
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // Empty when the workspace does not exist yet — Hyprland only tracks a
  // workspace once something puts it on a monitor.
  function workspaceMonitorName(id) {
    var workspace = root.workspaceById(id)
    return workspace && workspace.monitor ? String(workspace.monitor.name || "") : ""
  }

  function dispatch(expression) {
    return "hyprctl dispatch " + Util.shellQuote(expression)
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run(root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // Pull the workspace onto the display whose bar was clicked, then focus it.
  //   - already here, or no monitor resolved: plain focus, unchanged behavior
  //   - lives on another display: move it over first
  //   - does not exist yet: focus this display first, so creating the
  //     workspace lands it here instead of on whatever was focused
  function summonWorkspace(id) {
    if (!root.bar) return

    var target = root.clickedMonitorName()
    var current = root.workspaceMonitorName(id)
    var focus = root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")

    if (target === "" || current === target) {
      root.bar.run(focus)
      return
    }

    var relocate = current === ""
      ? root.dispatch("hl.dsp.focus({ monitor = \"" + target + "\" })")
      : root.dispatch("hl.dsp.workspace.move({ workspace = \"" + id + "\", monitor = \"" + target + "\" })")

    root.bar.run(relocate + " && " + focus)
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        // Right click keeps the old behavior: go to the workspace where it is.
        onPressed: function(button) {
          if (button === Qt.RightButton) root.focusWorkspace(modelData)
          else root.summonWorkspace(modelData)
        }
      }
    }
  }
}
