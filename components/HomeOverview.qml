import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

Item {
  id: root

  property color accent: "#f2b300"
  property color foreground: "#f8f9fa"
  property color mutedForeground: Qt.rgba(1, 1, 1, 0.58)
  property bool hasTrack: false
  property bool isPlaying: false
  property bool canPlayPause: false
  property bool canGoPrevious: false
  property bool canGoNext: false
  property string mediaTitle: ""
  property string mediaArtist: ""
  property string playerName: ""
  property bool timerActive: false
  property bool timerRunning: false
  property int timerLeft: 0
  property string timerName: ""
  property int availableAgents: 0
  property bool batteryAvailable: false
  property int batteryPct: -1
  property string batteryStatus: "Unavailable"
  property int systemVolume: 0
  property bool systemMuted: false
  property bool nightlightEnabled: false

  signal navigate(string page)
  signal actionRequested(string action)

  readonly property var entries: [
    { key: "music", title: "NOW PLAYING", icon: "♫" },
    { key: "timer", title: "FOCUS", icon: "◷" },
    { key: "agents", title: "AI TOOLS", icon: "⌘" },
    { key: "system", title: "SYSTEM", icon: "◫" }
  ]

  function headline(key) {
    if (key === "music") return hasTrack ? mediaTitle : "Nothing playing"
    if (key === "timer") return timerActive ? formatTime(timerLeft) : "Start a focus session"
    if (key === "agents") return availableAgents + " tools ready"
    return batteryAvailable ? batteryPct + "% battery" : systemVolume + "% volume"
  }

  function caption(key) {
    if (key === "music") return hasTrack ? (mediaArtist || playerName) : "Open media controls"
    if (key === "timer") return timerActive ? (timerName || "Focus session") : "25 · 45 · 60 minute presets"
    if (key === "agents") return "Codex, Claude and local tools"
    return batteryAvailable ? batteryStatus : (systemMuted ? "Muted" : "Audio controls")
  }

  function focusActionLabel() {
    if (!timerActive) return "Start 25 min focus"
    return timerRunning ? "Pause focus" : "Resume focus"
  }

  function formatTime(seconds) {
    var value = Math.max(0, Math.floor(seconds))
    return Math.floor(value / 60) + ":" + ("0" + (value % 60)).slice(-2)
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.space(10)

    GridLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      columns: 2
      rowSpacing: Style.space(9)
      columnSpacing: Style.space(9)

      Repeater {
        model: root.entries

        Rectangle {
          id: tile
          required property var modelData
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Style.space(15)
          color: pointerHover.hovered
            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.13)
            : Qt.rgba(1, 1, 1, 0.045)
          border.color: pointerHover.hovered
            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.38)
            : Qt.rgba(1, 1, 1, 0.09)

          Behavior on color { ColorAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }
          Behavior on border.color { ColorAnimation { duration: Style.duration(140); easing.type: Easing.OutCubic } }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.space(13)
            spacing: Style.space(5)

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: tile.modelData.icon
                color: root.accent
                font.pixelSize: Style.space(16)
              }
              Item { Layout.fillWidth: true }
              Rectangle {
                width: Style.space(24)
                height: Style.space(24)
                radius: Style.space(8)
                color: Qt.rgba(1, 1, 1, 0.06)
                Text {
                  anchors.centerIn: parent
                  text: "↗"
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.65)
                  font.pixelSize: Style.space(12)
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.navigate(tile.modelData.key)
                }
              }
            }

            Text {
              text: tile.modelData.title
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.5)
              font.family: Style.font.family
              font.pixelSize: Style.space(9)
              font.weight: Font.DemiBold
              font.letterSpacing: Style.space(0.7)
            }

            Text {
              Layout.fillWidth: true
              text: root.headline(tile.modelData.key)
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.space(14)
              font.weight: Font.DemiBold
              color: root.foreground
            }

            Text {
              Layout.fillWidth: true
              text: root.caption(tile.modelData.key)
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.space(10)
              color: root.mutedForeground
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(5)
              visible: tile.modelData.key === "music"
              Repeater {
                model: [
                  { label: "Prev", action: "media-previous", enabled: root.canGoPrevious },
                  { label: root.isPlaying ? "Pause" : "Play", action: "media-toggle", enabled: root.canPlayPause },
                  { label: "Next", action: "media-next", enabled: root.canGoNext }
                ]
                Rectangle {
                  id: mediaButton
                  required property var modelData
                  Layout.fillWidth: true
                  height: Style.space(28)
                  radius: Style.space(8)
                  color: Qt.rgba(1, 1, 1, mediaButton.modelData.enabled ? 0.09 : 0.035)
                  Text {
                    anchors.centerIn: parent
                    text: mediaButton.modelData.label
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, mediaButton.modelData.enabled ? 0.86 : 0.32)
                    font.family: Style.font.family
                    font.pixelSize: Style.space(9)
                    font.weight: Font.DemiBold
                  }
                  MouseArea {
                    anchors.fill: parent
                    enabled: mediaButton.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.actionRequested(mediaButton.modelData.action)
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: Style.space(28)
              radius: Style.space(8)
              color: Qt.rgba(1, 1, 1, 0.09)
              visible: tile.modelData.key === "timer"
              Text {
                anchors.centerIn: parent
                text: root.focusActionLabel()
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.space(9)
                font.weight: Font.DemiBold
              }
              MouseArea {
                anchors.fill: parent
                visible: tile.modelData.key === "timer"
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionRequested("focus-toggle")
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(5)
              visible: tile.modelData.key === "agents"
              Rectangle {
                Layout.fillWidth: true
                height: Style.space(28)
                radius: Style.space(8)
                color: Qt.rgba(1, 1, 1, 0.09)
                Text {
                  anchors.centerIn: parent
                  text: "Open AI tools"
                  color: root.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.space(9)
                  font.weight: Font.DemiBold
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.navigate("agents")
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(5)
              visible: tile.modelData.key === "system"
              Repeater {
                model: [
                  { label: root.systemMuted ? "Unmute" : "Mute", action: "toggle-mute" },
                  { label: root.nightlightEnabled ? "Night light on" : "Night light", action: "toggle-nightlight" }
                ]
                Rectangle {
                  id: systemButton
                  required property var modelData
                  Layout.fillWidth: true
                  height: Style.space(28)
                  radius: Style.space(8)
                  color: Qt.rgba(1, 1, 1, 0.09)
                  Text {
                    anchors.centerIn: parent
                    text: systemButton.modelData.label
                    color: root.foreground
                    font.family: Style.font.family
                    font.pixelSize: Style.space(9)
                    font.weight: Font.DemiBold
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.actionRequested(systemButton.modelData.action)
                  }
                }
              }
            }
          }

          HoverHandler {
            id: pointerHover
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      text: "Use the buttons or arrows to open controls"
      horizontalAlignment: Text.AlignHCenter
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.38)
      font.family: Style.font.family
      font.pixelSize: Style.space(9)
    }
  }
}
