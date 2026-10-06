import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "harshith.dynamic-island"
  ipcTarget: "harshith.dynamic-island.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string scriptPath:
    Qt.resolvedUrl("island-backend.sh").toString().replace(/^file:\/\//, "")

  property bool isPlaying: false
  property string mediaTitle: "No Media Playing"
  property string mediaArtist: "Play Spotify, YouTube or VLC"
  property string mediaStatus: "Stopped"
  property string artUrl: ""
  property int mediaPosition: 0
  property int mediaDuration: 0
  property bool draggingSeek: false

  function timeLabel(seconds) {
    var value = Math.max(0, Math.floor(seconds))
    var minutes = Math.floor(value / 60)
    var remaining = value % 60
    return minutes + ":" + (remaining < 10 ? "0" : "") + remaining
  }

  function seekTo(seconds) {
    root.mediaAction("seek", Math.max(0, Math.min(root.mediaDuration, Math.floor(seconds))))
  }
  property int batteryPct: -1
  property string batteryStatus: "Unavailable"
  property bool batteryAvailable: false
  property bool antigravityAvailable: false
  property bool claudeAvailable: false

  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property color bg: Color.popups.background
  readonly property color accent: Color.accent
  readonly property string fontFam: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    root.refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function refresh() {
    if (stateProc.running) return
    stateProc.command = ["bash", scriptPath, "get"]
    stateProc.running = true
  }

  function mediaAction(action, argument) {
    if (actionProc.running) return
    actionProc.command = argument === undefined ? ["bash", scriptPath, action] : ["bash", scriptPath, action, String(argument)]
    actionProc.running = true
  }

  function agentSummary() {
    var names = []
    if (root.antigravityAvailable) names.push("Antigravity")
    if (root.claudeAvailable) names.push("Claude Code")
    return names.length > 0 ? names.join(" · ") + " available" : "No supported local agent detected"
  }

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
            root.mediaTitle = data.media.title || "No Media Playing"
            root.mediaArtist = data.media.artist || "Play Spotify, YouTube or VLC"
            root.artUrl = data.media.art_url || ""
            root.mediaDuration = Number(data.media.duration) || 0
            if (!root.draggingSeek) root.mediaPosition = Number(data.media.position) || 0
          }
          if (data.battery) {
            root.batteryAvailable = data.battery.available === true
            root.batteryPct = data.battery.pct !== null && data.battery.pct !== undefined ? data.battery.pct : -1
            root.batteryStatus = data.battery.status || "Unavailable"
          }
          if (data.agents) {
            root.antigravityAvailable = data.agents.antigravity && data.agents.antigravity.available === true
            root.claudeAvailable = data.agents.claude_code && data.agents.claude_code.available === true
          }
        } catch(e) {}
      }
    }
  }

  Process {
    id: actionProc
    running: false
    onExited: root.refresh()
  }

  Timer {
    interval: 1500
    running: root.opened && root.mediaDuration > 0
    repeat: true
    onTriggered: root.refresh()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(500))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    ScrollView {
      id: scrollArea
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -panel.padding
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Column {
        id: panelColumn
        width: scrollArea.availableWidth
        spacing: Style.space(14)

        // Glassmorphism Hero Media Card
        Rectangle {
          width: parent.width
          height: Style.space(144)
          radius: Style.space(12)
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
          border.color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(12)
            spacing: Style.space(12)

            // Album Vinyl / Art Placeholder
            Rectangle {
              width: Style.space(76)
              height: Style.space(76)
              radius: Style.space(10)
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
              border.color: root.accent
              border.width: 1.5
              clip: true

              Image {
                id: localAlbumArt
                anchors.fill: parent
                anchors.margins: Style.space(2)
                visible: root.isPlaying && root.artUrl.startsWith("file://")
                source: visible ? root.artUrl : ""
                sourceSize: Qt.size(256, 256)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }

              Text {
                anchors.centerIn: parent
                visible: localAlbumArt.status !== Image.Ready
                textFormat: Text.PlainText
                text: root.isPlaying ? "💿" : "󰝚"
                font.pixelSize: Style.space(28)
              }

              RotationAnimation on rotation {
                running: root.isPlaying
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 6000
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(3)

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.mediaTitle
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
                color: root.fg
              }

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.mediaArtist
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                color: Qt.darker(root.fg, 1.4)
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)

                Text {
                  text: root.timeLabel(seekSlider.pressed ? seekSlider.value : root.mediaPosition)
                  color: root.fg
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                }

                Slider {
                  id: seekSlider
                  Layout.fillWidth: true
                  from: 0
                  to: Math.max(1, root.mediaDuration)
                  value: root.mediaPosition
                  enabled: root.mediaDuration > 0
                  onMoved: root.mediaPosition = value
                  onPressedChanged: {
                    root.draggingSeek = pressed
                    if (!pressed && root.mediaDuration > 0) root.seekTo(value)
                  }
                }

                Text {
                  text: root.mediaDuration > 0 ? root.timeLabel(root.mediaDuration) : "--:--"
                  color: root.fg
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                }
              }

              // Media Control Buttons
              Row {
                spacing: Style.space(12)
                topPadding: Style.space(4)

                Rectangle {
                  width: Style.space(28)
                  height: Style.space(28)
                  radius: Style.space(6)
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "⏮"
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.mediaAction("previous")
                  }
                }

                Rectangle {
                  width: Style.space(32)
                  height: Style.space(28)
                  radius: Style.space(6)
                  color: root.accent

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: root.isPlaying ? "⏸" : "▶"
                    color: "#ffffff"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.mediaAction("play-pause")
                  }
                }

                Rectangle {
                  width: Style.space(28)
                  height: Style.space(28)
                  radius: Style.space(6)
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "⏭"
                    font.pixelSize: Style.font.caption
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.mediaAction("next")
                  }
                }
              }
            }
          }
        }

        PanelSeparator { width: parent.width }

        // AI Agent Status Tile
        Rectangle {
          width: parent.width
          height: Style.space(60)
          radius: Style.space(10)
          color: root.antigravityAvailable || root.claudeAvailable ? Qt.rgba(0.2, 0.6, 1.0, 0.12) : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
          border.color: root.antigravityAvailable || root.claudeAvailable ? Qt.rgba(0.2, 0.6, 1.0, 0.3) : Qt.rgba(1.0, 1.0, 1.0, 0.12)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(10)

            Text {
              textFormat: Text.PlainText
              text: "🤖"
              font.pixelSize: Style.font.title
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 1

              Text {
                textFormat: Text.PlainText
                text: root.antigravityAvailable || root.claudeAvailable ? "AI Agent Sentinel" : "AI Agent Sentinel (not detected)"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                font.bold: true
                color: "#44aaff"
              }

              Text {
                textFormat: Text.PlainText
                text: root.agentSummary()
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                color: Qt.darker(root.fg, 1.4)
              }
            }

            Rectangle {
              width: Style.space(56)
              height: Style.space(24)
              radius: Style.space(4)
              color: root.antigravityAvailable || root.claudeAvailable ? "#38ef7d" : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: root.antigravityAvailable || root.claudeAvailable ? "Detected" : "Offline"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.antigravityAvailable || root.claudeAvailable ? "#000000" : root.fg
              }
            }
          }
        }

        PanelSeparator { width: parent.width }

        // Battery & Charging Vitals
        Rectangle {
          width: parent.width
          height: Style.space(44)
          radius: Style.space(8)
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)

            Row {
              spacing: Style.space(6)
              Text { textFormat: Text.PlainText; text: "🔋"; font.pixelSize: Style.font.body }
              Text {
                textFormat: Text.PlainText
                text: root.batteryAvailable && root.batteryPct >= 0 ? "Battery: " + root.batteryPct + "%" : "Battery unavailable"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.fg
              }
            }

            Item { Layout.fillWidth: true }

            Text {
              textFormat: Text.PlainText
              text: root.batteryStatus
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              color: root.batteryAvailable ? "#38ef7d" : Qt.darker(root.fg, 1.3)
            }
          }
        }
      }
    }
  }
}
