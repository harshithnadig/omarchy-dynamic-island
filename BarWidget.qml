import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "harshith.dynamic-island"

  readonly property string scriptPath:
    Qt.resolvedUrl("island-backend.sh").toString().replace(/^file:\/\//, "")

  property bool isPlaying: false
  property string mediaTitle: ""
  property string mediaArtist: ""
  property string mediaStatus: "Stopped"
  property int batteryPct: 80
  property string batteryStatus: "Discharging"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = islandCapsule
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function refresh() {
    stateProc.command = ["bash", scriptPath, "get"]
    stateProc.running = true
  }

  implicitWidth: islandCapsule.width
  implicitHeight: islandCapsule.height

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: stateProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.media) {
            root.isPlaying = data.media.playing === true
            root.mediaStatus = data.media.status || "Stopped"
            root.mediaTitle = data.media.title || ""
            root.mediaArtist = data.media.artist || ""
          }
          if (data.battery) {
            root.batteryPct = data.battery.pct || 100
            root.batteryStatus = data.battery.status || ""
          }
        } catch(e) {}
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // Liquid Glass Capsule (Morphing Spring Island)
  Rectangle {
    id: islandCapsule
    height: Style.space(30)
    width: root.isPlaying && root.mediaTitle !== ""
      ? Math.min(Style.space(260), titleText.implicitWidth + Style.space(90))
      : Style.space(84)

    radius: height / 2
    color: Qt.rgba(0.08, 0.09, 0.14, 0.72)
    border.color: root.opened ? Color.accent : Qt.rgba(1.0, 1.0, 1.0, 0.18)
    border.width: 1.2

    Behavior on width {
      NumberAnimation {
        duration: 380
        easing.type: Easing.OutBack
        easing.overshoot: 1.15
      }
    }

    Behavior on border.color {
      ColorAnimation { duration: 200 }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(6)

      // Dynamic Island Glowing Glyph / Pulse
      Rectangle {
        width: Style.space(16)
        height: Style.space(16)
        radius: width / 2
        color: root.isPlaying ? Color.accent : Qt.rgba(1.0, 1.0, 1.0, 0.1)

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.isPlaying ? "󰝚" : "🏝️"
          font.pixelSize: Style.space(10)
          color: root.isPlaying ? "#ffffff" : Color.foreground
        }

        SequentialAnimation on scale {
          running: root.isPlaying
          loops: Animation.Infinite
          PropertyAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutQuad }
          PropertyAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
        }
      }

      // Title Text
      Text {
        id: titleText
        Layout.fillWidth: true
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: root.isPlaying && root.mediaTitle !== "" ? root.mediaTitle : "Island"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        color: root.isPlaying ? Color.foreground : Qt.darker(Color.foreground, 1.3)
      }

      // Live 4-Bar Audio Visualizer (Dancing Waveform)
      Row {
        visible: root.isPlaying
        spacing: 2
        height: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: 4
          Rectangle {
            id: barItem
            width: 2.5
            height: Style.space(4)
            radius: 1.2
            color: Color.accent

            SequentialAnimation on height {
              running: root.isPlaying
              loops: Animation.Infinite
              PropertyAnimation {
                to: Style.space(4 + (index % 2 == 0 ? 8 : 12))
                duration: 200 + (index * 80)
                easing.type: Easing.InOutQuad
              }
              PropertyAnimation {
                to: Style.space(3)
                duration: 200 + (index * 80)
                easing.type: Easing.InOutQuad
              }
            }
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: root.togglePanel()
    }
  }
}
