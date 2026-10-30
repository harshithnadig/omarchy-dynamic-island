import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Dynamic Island Pro Service
// Always-visible top-center Apple-style morphing Dynamic Island.
// Transparent layer shell with input strictly masked to the morphing pill.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window
      required property var modelData

      screen: modelData
      anchors { top: true; left: true; right: true }
      implicitHeight: core.item && core.item.isExpanded ? Style.space(600) : Style.space(90)
      Behavior on implicitHeight {
        NumberAnimation {
          duration: Style.duration(core.item && core.item.isExpanded ? 240 : 160)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "harshith-dynamic-island"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: core.item && core.item.isExpanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      // Perfect click-through masking
      mask: Region {
        item: core.item && core.item.isExpanded
          ? dismissArea
          : (core.item ? core.item.maskItem : null)

        Region {
          item: core.item && !core.item.isExpanded && !core.item.isPeeking && core.item.satelliteItem && core.item.satelliteItem.visible
            ? core.item.satelliteItem : null
        }
      }

      Item {
        id: dismissArea
        anchors.fill: parent
      }

      FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape && core.item && core.item.isExpanded) {
            core.item.isExpanded = false
            event.accepted = true
          }
        }

        Loader {
          id: core
          anchors.fill: parent
          active: true
          source: Qt.resolvedUrl("IslandCore.qml")
        }
      }
    }
  }
}
