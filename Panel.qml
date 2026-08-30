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
  property int batteryPct: 80
  property string batteryStatus: "Discharging"

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
    stateProc.command = ["bash", scriptPath, "get"]
    stateProc.running = true
  }

  function mediaAction(action) {
    actionProc.command = ["bash", scriptPath, action]
    actionProc.running = true
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
          }
          if (data.battery) {
            root.batteryPct = data.battery.pct || 100
            root.batteryStatus = data.battery.status || ""
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
          height: Style.space(110)
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

              Text {
                anchors.centerIn: parent
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
          color: Qt.rgba(0.2, 0.6, 1.0, 0.12)
          border.color: Qt.rgba(0.2, 0.6, 1.0, 0.3)
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
                text: "AI Agent Sentinel (Active)"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                font.bold: true
                color: "#44aaff"
              }

              Text {
                textFormat: Text.PlainText
                text: "Google Antigravity & Claude Code linked"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                color: Qt.darker(root.fg, 1.4)
              }
            }

            Rectangle {
              width: Style.space(56)
              height: Style.space(24)
              radius: Style.space(4)
              color: "#38ef7d"

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "Online"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                font.bold: true
                color: "#000000"
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
                text: "Battery: " + root.batteryPct + "%"
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
              color: "#38ef7d"
            }
          }
        }
      }
    }
  }
}
