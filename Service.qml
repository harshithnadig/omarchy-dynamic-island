import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Dynamic Island Pro Service
// Full-width transparent overlay layer. Input is strictly constrained to the
// top-center reveal sensor and the interactive morphing island capsule.
Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window
      required property var modelData

      property bool revealed: false
      property bool sensorHovered: false
      property bool islandHovered: false

      readonly property bool hasActiveEvent: core.item
        ? (core.item.isPlaying || core.item.timerActive || core.item.stopwatchVisible || core.item.isRecording)
        : false
      readonly property bool isPinned: core.item ? core.item.isPinned : false
      readonly property bool shouldStayRevealed: isPinned || hasActiveEvent || (core.item && core.item.opened)

      onShouldStayRevealedChanged: {
        if (shouldStayRevealed) {
          collapseTimer.stop()
          hideTimer.stop()
          window.revealed = true
        } else if (!sensorHovered && !islandHovered && !(core.item && core.item.opened)) {
          window.scheduleCollapse()
        }
      }

      function scheduleCollapse() {
        if (window.shouldStayRevealed) {
          if (core.item && !window.sensorHovered && !window.islandHovered && !core.item.panelHovered) {
            core.item.hoverExpanded = false
          }
          return
        }
        if (!sensorHovered && !islandHovered
            && !(core.item && core.item.opened && core.item.panelHovered)) {
          collapseTimer.restart()
        }
      }

      Timer {
        id: revealTimer
        interval: 100
        onTriggered: {
          if (!window.sensorHovered && !window.islandHovered) return
          window.revealed = true
          expandTimer.restart()
        }
      }

      Timer {
        id: expandTimer
        interval: 130
        onTriggered: {
          if ((window.sensorHovered || window.islandHovered) && core.item)
            core.item.hoverExpanded = true
        }
      }

      Timer {
        id: collapseTimer
        interval: 850
        onTriggered: {
          if (!window.sensorHovered && !window.islandHovered) {
            if (core.item && core.item.opened && !core.item.panelHovered) core.item.close()
            if (core.item) core.item.hoverExpanded = false
            if (!window.shouldStayRevealed) {
              hideTimer.restart()
            }
          }
        }
      }

      Timer {
        id: hideTimer
        interval: 120
        onTriggered: {
          if (!window.sensorHovered && !window.islandHovered && !window.shouldStayRevealed
              && !(core.item && core.item.opened && core.item.panelHovered)) {
            window.revealed = false
          }
        }
      }

      screen: modelData
      anchors { top: true; left: true; right: true }
      implicitHeight: Math.max(90, Style.space(90))
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "harshith-dynamic-island"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      mask: Region {
        item: (window.revealed || window.shouldStayRevealed) ? islandHitArea : null
        Region { item: revealSensor }
      }

      // Thin Top-Center Hover Strip
      Item {
        id: revealSensor
        x: Math.round((parent.width - width) / 2)
        y: 0
        width: 320
        height: 14

        HoverHandler {
          onHoveredChanged: {
            window.sensorHovered = hovered
            if (hovered) {
              collapseTimer.stop()
              hideTimer.stop()
              revealTimer.restart()
            } else {
              revealTimer.stop()
              expandTimer.stop()
              window.scheduleCollapse()
            }
          }
        }

        // Notch indicator line
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: 1
          width: 60
          height: 2.5
          radius: 1.5
          color: Qt.rgba(1, 1, 1, 0.22)
          opacity: (window.sensorHovered && !window.revealed && !window.shouldStayRevealed) ? 1 : 0
          Behavior on opacity { NumberAnimation { duration: 180 } }
        }
      }

      // Morphing Island Target Area
      Item {
        id: islandHitArea
        x: Math.round((parent.width - width) / 2)
        y: 0
        width: Math.max(540, core.item ? core.item.implicitWidth + Style.space(40) : 0)
        height: Math.max(82, Style.space(82))

        Loader {
          id: core
          anchors.horizontalCenter: parent.horizontalCenter
          active: true
          source: Qt.resolvedUrl("IslandCore.qml")
          onLoaded: {
            item.bar = null
            item.settings = null
            Qt.callLater(function() {
              item.bar = null
              item.settings = null
            })
          }
          opacity: (window.revealed || window.shouldStayRevealed) ? 1 : 0
          y: (window.revealed || window.shouldStayRevealed) ? 7 : 0
          scale: (window.revealed || window.shouldStayRevealed) ? 1 : 0.92
          visible: opacity > 0

          Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
          Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
          Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.72; mass: 0.8 } }
        }

        HoverHandler {
          onHoveredChanged: {
            window.islandHovered = hovered
            if (hovered) {
              collapseTimer.stop()
              hideTimer.stop()
              window.revealed = true
              expandTimer.restart()
            } else {
              window.scheduleCollapse()
            }
          }
        }
      }

      Connections {
        target: core.item
        function onOpenedChanged() {
          if (core.item && core.item.opened) {
            window.revealed = true
            collapseTimer.stop()
          } else {
            window.scheduleCollapse()
          }
        }
        function onPanelHoveredChanged() {
          if (core.item && core.item.panelHovered) {
            collapseTimer.stop()
          } else {
            window.scheduleCollapse()
          }
        }
      }
    }
  }
}
