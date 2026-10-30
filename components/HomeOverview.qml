import QtQuick
import QtQuick.Layouts
import qs.Commons

Item {
  id: root

  property color accent: "#f2b300"
  property color foreground: "#f8f9fa"
  property color mutedForeground: Qt.rgba(1, 1, 1, 0.58)
  property bool hasTrack: false
  property string mediaTitle: ""
  property string mediaArtist: ""
  property string playerName: ""
  property bool timerActive: false
  property int timerLeft: 0
  property string timerName: ""
  property int availableAgents: 0
  property bool batteryAvailable: false
  property int batteryPct: -1
  property string batteryStatus: "Unavailable"
  property int systemVolume: 0
  property bool systemMuted: false

  signal navigate(string page)

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
          color: pointer.containsMouse
            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.13)
            : Qt.rgba(1, 1, 1, 0.045)
          border.color: pointer.containsMouse
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
              Text {
                text: "↗"
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)
                font.pixelSize: Style.space(12)
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
          }

          MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.navigate(tile.modelData.key)
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      text: "Choose a card to jump into its controls"
      horizontalAlignment: Text.AlignHCenter
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.38)
      font.family: Style.font.family
      font.pixelSize: Style.space(9)
    }
  }
}
