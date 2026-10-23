import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "harshith.dynamic-island"
  ipcTarget: "harshith.dynamic-island.panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool pointerInside: false
  readonly property var island: hostWidget || root
  readonly property color fg: bar ? bar.foreground : Commons.Color.popups.text
  readonly property color accent: Commons.Color.accent
  readonly property color glass: Qt.rgba(fg.r, fg.g, fg.b, 0.05)
  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  readonly property var workspaceList: Hyprland.workspaces.values
  readonly property var currentWindows: focusedWorkspace ? focusedWorkspace.toplevels.values : []
  readonly property var focusedWindow: Hyprland.activeToplevel

  property int timerTotal: 0
  property int timerLeft: 0
  property double timerDeadline: 0
  property bool timerRunning: false
  property bool timerFinished: false
  property string timerName: ""
  property string timerMode: "quick"
  property int focusSessions: 0
  property string draftSessionName: ""
  property bool pinIsland: false
  property bool soundEnabled: true

  property bool stateReady: false
  property bool stateTouched: false

  property int stopwatchElapsed: 0
  property int stopwatchBaseSeconds: 0
  property double stopwatchStartedAt: 0
  property bool stopwatchRunning: false

  property string activePage: "home"
  property var currentDate: new Date()
  property var agentsData: ({})

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function openPage(page) { activePage = page; open() }

  function activateWorkspace(workspace) {
    if (!workspace) return
    workspace.activate()
    root.close()
  }

  function activateWindow(window) {
    if (!window) return
    window.activate()
    root.close()
  }

  function nextOmarchyBackground() {
    Quickshell.execDetached(["omarchy", "theme", "bg", "next"])
  }

  function openOmarchyThemeSwitcher() {
    Quickshell.execDetached(["omarchy", "theme", "switcher"])
  }

  function takeScreenshot() {
    Quickshell.execDetached(["omarchy-capture-screenshot"])
    root.close()
  }

  function launchTerminal(cmd) {
    if (cmd) Quickshell.execDetached(["foot", "-e", "bash", "-c", cmd + "; exec bash"])
    else Quickshell.execDetached(["foot"])
    root.close()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function cleanArtUrl(raw) {
    if (!raw || typeof raw !== "string") return ""
    var trimmed = raw.trim()
    if (trimmed === "") return ""
    if (trimmed.startsWith("file://") || trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
    if (trimmed.startsWith("/")) return "file://" + trimmed
    return ""
  }

  function formatTime(seconds) {
    var value = Math.max(0, Math.floor(seconds))
    var hours = Math.floor(value / 3600)
    var minutes = Math.floor((value % 3600) / 60)
    var remainder = value % 60
    return hours > 0
      ? hours + ":" + ("0" + minutes).slice(-2) + ":" + ("0" + remainder).slice(-2)
      : minutes + ":" + ("0" + remainder).slice(-2)
  }

  function playChime() {
    if (!soundEnabled) return
    Quickshell.execDetached(["canberra-gtk-play", "-i", "complete"])
  }

  function persistState() {
    stateTouched = true
    if (!stateReady) return
    stateFile.setText(JSON.stringify({
      version: 3,
      timerTotal: timerTotal,
      timerLeft: timerLeft,
      timerDeadline: timerDeadline,
      timerRunning: timerRunning,
      timerFinished: timerFinished,
      timerName: timerName,
      timerMode: timerMode,
      focusSessions: focusSessions,
      pinIsland: pinIsland,
      soundEnabled: soundEnabled,
      stopwatchElapsed: stopwatchElapsed,
      stopwatchBaseSeconds: stopwatchBaseSeconds,
      stopwatchStartedAt: stopwatchStartedAt,
      stopwatchRunning: stopwatchRunning
    }))
  }

  function restoreState() {
    if (!stateReady) return
    if (stateTouched) { persistState(); return }
    try {
      var saved = JSON.parse(stateFile.text() || "{}")
      if (saved.version !== 1 && saved.version !== 2 && saved.version !== 3) return
      timerTotal = Math.max(0, Number(saved.timerTotal) || 0)
      timerLeft = Math.max(0, Number(saved.timerLeft) || 0)
      timerDeadline = Number(saved.timerDeadline) || 0
      timerFinished = saved.timerFinished === true
      timerName = typeof saved.timerName === "string" ? saved.timerName : ""
      timerMode = typeof saved.timerMode === "string" ? saved.timerMode : "quick"
      focusSessions = Math.max(0, Number(saved.focusSessions) || 0)
      pinIsland = saved.pinIsland === true
      soundEnabled = saved.soundEnabled !== false

      stopwatchBaseSeconds = Math.max(0, Number(saved.stopwatchBaseSeconds) || 0)
      stopwatchStartedAt = Number(saved.stopwatchStartedAt) || 0
      stopwatchRunning = saved.stopwatchRunning === true && stopwatchStartedAt > 0
      stopwatchElapsed = Math.max(0, Number(saved.stopwatchElapsed) || stopwatchBaseSeconds)
      updateStopwatch()

      if (saved.timerRunning === true && timerDeadline > 0) {
        timerRunning = true
        updateActivities()
      }
    } catch (e) {}
  }

  function updateStopwatch() {
    if (stopwatchRunning && stopwatchStartedAt > 0)
      stopwatchElapsed = stopwatchBaseSeconds + Math.floor((Date.now() - stopwatchStartedAt) / 1000)
  }

  function updateActivities() {
    var now = Date.now()
    if (timerRunning) {
      timerLeft = Math.max(0, Math.ceil((timerDeadline - now) / 1000))
      if (timerLeft === 0) {
        timerRunning = false
        timerFinished = true
        timerDeadline = 0
        if (timerMode === "focus" || timerMode === "deep") focusSessions += 1
        persistState()
        root.playChime()
        Quickshell.execDetached(["notify-send", "-a", "Dynamic Island Pro",
          timerName || "Session complete", timerMode === "focus" || timerMode === "deep"
            ? "Focus session " + focusSessions + " complete. Great work!"
            : "Your timer is done."])
      }
    }
    updateStopwatch()
  }

  function startTimer(minutes, name, mode) {
    timerTotal = minutes * 60
    timerLeft = timerTotal
    timerName = name || "Quick timer"
    timerMode = mode || "quick"
    timerDeadline = Date.now() + timerLeft * 1000
    timerFinished = false
    timerRunning = true
    persistState()
    updateActivities()
  }

  function toggleTimer() {
    if (timerRunning) {
      updateActivities()
      if (!timerRunning) return
      timerRunning = false
      timerDeadline = 0
    } else if (timerLeft > 0) {
      timerDeadline = Date.now() + timerLeft * 1000
      timerRunning = true
      timerFinished = false
    }
    persistState()
  }

  function adjustTimer(deltaSeconds) {
    if (!timerRunning && timerLeft <= 0) return
    timerLeft = Math.max(0, timerLeft + deltaSeconds)
    timerTotal = Math.max(timerLeft, timerTotal + deltaSeconds)
    if (timerLeft === 0) { clearTimer(); return }
    if (timerRunning) timerDeadline = Date.now() + timerLeft * 1000
    persistState()
  }

  function clearTimer() {
    timerRunning = false
    timerTotal = 0
    timerLeft = 0
    timerDeadline = 0
    timerFinished = false
    timerName = ""
    timerMode = "quick"
    persistState()
  }

  function toggleStopwatch() {
    if (stopwatchRunning) {
      updateStopwatch()
      stopwatchBaseSeconds = stopwatchElapsed
      stopwatchRunning = false
      stopwatchStartedAt = 0
    } else {
      stopwatchBaseSeconds = stopwatchElapsed
      stopwatchStartedAt = Date.now()
      stopwatchRunning = true
    }
    persistState()
  }

  function resetStopwatch() {
    stopwatchRunning = false
    stopwatchElapsed = 0
    stopwatchBaseSeconds = 0
    stopwatchStartedAt = 0
    persistState()
  }

  function seekFromClick(mouseX, width) {
    if (island.duration <= 0 || width <= 0) return
    var seconds = Math.max(0, Math.min(island.duration, Math.round(island.duration * mouseX / width)))
    island.mediaAction("seek", seconds)
  }

  FileView {
    id: stateFile
    path: Quickshell.statePath("harshith.dynamic-island.json")
    printErrors: false
    onLoaded: {
      root.stateReady = true
      root.restoreState()
    }
    onLoadFailed: {
      root.stateReady = true
      if (root.stateTouched) root.persistState()
    }
  }

  Timer {
    id: activityClock
    interval: 1000
    repeat: true
    running: root.timerRunning || root.stopwatchRunning
    onTriggered: root.updateActivities()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(410))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(570))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }

    Controls.ScrollView {
      id: scrollArea
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -panel.padding
      clip: true
      HoverHandler {
        onHoveredChanged: root.pointerInside = hovered
      }
      Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
      Controls.ScrollBar.vertical.policy: contentColumn.implicitHeight > height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff

      Column {
        id: contentColumn
        width: scrollArea.availableWidth
        spacing: Style.space(14)

        // Header Title & Active Status
        RowLayout {
          width: parent.width
          spacing: Style.space(8)
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
              text: root.activePage === "home" ? "Dynamic Island Pro"
                : root.activePage === "desk" ? "Hyprland Desk"
                : root.activePage === "music" ? "Now Playing"
                : root.activePage === "agents" ? "AI & Models Studio" : "Focus Studio"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.weight: Font.DemiBold
              color: root.fg
            }
            Text {
              text: root.activePage === "desk" ? "Hyprland spaces and open windows"
                : root.activePage === "timer" ? "Focus and break countdowns"
                : root.activePage === "music" ? (root.island.isPlaying ? "Playing on " + root.island.playerName : "Media Transport")
                : root.activePage === "agents" ? "Autonomous coding agents & local LLMs"
                : "Top-center liquid glass activity hub"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.62)
            }
          }
          Rectangle {
            Layout.preferredWidth: Style.space(8)
            Layout.preferredHeight: Style.space(8)
            radius: width / 2
            color: root.island.isPlaying || root.timerRunning
              ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.28)
          }
        }

        // Top Navigation Bar
        RowLayout {
          width: parent.width
          spacing: Style.space(4)
          Repeater {
            model: [
              { key: "home", label: "Home" },
              { key: "music", label: "Music" },
              { key: "timer", label: "Focus" },
              { key: "agents", label: "Agents" },
              { key: "desk", label: "Desk" }
            ]
            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              height: Style.space(34)
              radius: Style.space(9)
              color: root.activePage === modelData.key
                ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15) : "transparent"
              border.color: root.activePage === modelData.key
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4) : "transparent"
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: modelData.label
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: root.activePage === parent.modelData.key ? Font.DemiBold : Font.Normal
                color: root.activePage === parent.modelData.key
                  ? root.fg : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.55)
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activePage = parent.modelData.key
              }
            }
          }
        }

        // ================= PAGE: HOME =================
        // Clock & Date Card
        Rectangle {
          visible: root.activePage === "home"
          width: parent.width
          radius: Style.space(14)
          color: root.glass
          border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
          border.width: 1
          height: Style.space(96)

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(14)
            spacing: Style.space(12)
            ColumnLayout {
              Layout.fillWidth: true
              spacing: 3
              Text {
                text: Qt.formatDateTime(root.currentDate, "h:mm AP")
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.space(28)
                font.weight: Font.DemiBold
                color: root.fg
              }
              Text {
                text: Qt.formatDate(root.currentDate, "dddd, d MMMM")
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.58)
              }
            }
            Rectangle {
              width: Style.space(48)
              height: Style.space(48)
              radius: Style.space(12)
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
              Text {
                anchors.centerIn: parent
                text: root.island.isPlaying ? "♫" : "🏝️"
                font.pixelSize: Style.space(22)
                color: root.accent
              }
            }
          }
          Timer {
            interval: 15000
            running: root.opened && root.activePage === "home"
            repeat: true
            onTriggered: root.currentDate = new Date()
          }
        }

        // Now Playing Quick Card
        Rectangle {
          visible: root.activePage === "home" && root.island.hasTrack
          width: parent.width
          height: Style.space(64)
          radius: Style.space(12)
          color: root.glass
          border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(10)

            Rectangle {
              width: Style.space(38)
              height: Style.space(38)
              radius: Style.space(9)
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
              clip: true
              Image {
                anchors.fill: parent
                visible: root.island.artUrl !== ""
                source: visible ? root.island.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
              Text {
                anchors.centerIn: parent
                visible: root.island.artUrl === ""
                text: "♫"
                color: root.accent
                font.pixelSize: Style.font.body
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2
              Text {
                Layout.fillWidth: true
                text: root.island.mediaTitle
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                font.weight: Font.DemiBold
                color: root.fg
              }
              Text {
                Layout.fillWidth: true
                text: root.island.mediaArtist || (root.island.isPlaying ? "Playing" : "Paused")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.58)
              }
            }

            Rectangle {
              width: Style.space(32)
              height: Style.space(32)
              radius: width / 2
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
              Text {
                anchors.centerIn: parent
                text: root.island.isPlaying ? "Ⅱ" : "▶"
                color: root.fg
                font.pixelSize: Style.font.caption
                font.weight: Font.Bold
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.island.mediaAction("play-pause")
              }
            }
          }
        }

        // Quick System Actions Grid
        Text {
          visible: root.activePage === "home"
          text: "Quick Actions"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.weight: Font.DemiBold
          color: root.fg
        }

        GridLayout {
          visible: root.activePage === "home"
          width: parent.width
          columns: 2
          rowSpacing: Style.space(8)
          columnSpacing: Style.space(8)

          // Pin Island Toggle
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(42)
            radius: Style.space(10)
            color: root.pinIsland ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.glass
            border.color: root.pinIsland ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)
              Text {
                text: "📌"
                font.pixelSize: Style.font.body
              }
              Text {
                text: root.pinIsland ? "Pinned Always" : "Auto-Collapse"
                color: root.fg
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.pinIsland = !root.pinIsland
                root.persistState()
              }
            }
          }

          // Screenshot Tool
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(42)
            radius: Style.space(10)
            color: root.glass
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)
              Text { text: "📸"; font.pixelSize: Style.font.body }
              Text {
                text: "Screenshot"
                color: root.fg
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.takeScreenshot()
            }
          }

          // Next Background
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(42)
            radius: Style.space(10)
            color: root.glass
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)
              Text { text: "▧"; color: root.accent; font.pixelSize: Style.font.body }
              Text {
                text: "Next Wallpaper"
                color: root.fg
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.nextOmarchyBackground()
            }
          }

          // Change Theme
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(42)
            radius: Style.space(10)
            color: root.glass
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)
              Text { text: "◐"; color: root.accent; font.pixelSize: Style.font.body }
              Text {
                text: "Change Theme"
                color: root.fg
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openOmarchyThemeSwitcher()
            }
          }
        }

        // Battery Status Row
        Rectangle {
          visible: root.activePage === "home"
          width: parent.width
          height: Style.space(44)
          radius: Style.space(10)
          color: root.glass
          border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(12)
            spacing: Style.space(8)

            Text {
              text: root.island.batteryPct >= 0 && root.island.batteryPct <= 20 ? "🪫" : "🔋"
              font.pixelSize: Style.font.body
            }
            Text {
              Layout.fillWidth: true
              text: root.island.batteryAvailable
                ? "Battery  " + root.island.batteryPct + "%  ·  " + root.island.batteryStatus
                : "Battery status unavailable"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.7)
            }
            Rectangle {
              visible: root.island.batteryAvailable
              Layout.preferredWidth: Style.space(48)
              Layout.preferredHeight: Style.space(6)
              radius: height / 2
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.island.batteryPct / 100))
                height: parent.height
                radius: height / 2
                color: root.island.batteryPct <= 15 ? "#ef4444" : root.island.batteryPct <= 30 ? "#f59e0b" : "#10b981"
              }
            }
          }
        }

        // ================= PAGE: MUSIC =================
        // Player Selection Chips
        ListView {
          visible: root.activePage === "music" && Mpris.players.values.length > 1
          width: parent.width
          height: visible ? Style.space(32) : 0
          orientation: ListView.Horizontal
          spacing: Style.space(6)
          clip: true
          model: Mpris.players

          header: Rectangle {
            width: Style.space(52)
            height: Style.space(28)
            radius: height / 2
            color: root.island.selectedPlayer === null
              ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24) : root.glass
            border.color: root.island.selectedPlayer === null ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: "Auto"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: root.fg
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.island.selectPlayer(null)
            }
          }

          delegate: Rectangle {
            required property var modelData
            width: Math.min(Style.space(145), playerChipText.implicitWidth + Style.space(24))
            height: Style.space(28)
            radius: height / 2
            color: root.island.currentPlayer === modelData
              ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24) : root.glass
            border.color: root.island.currentPlayer === modelData ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1
            Text {
              id: playerChipText
              anchors.centerIn: parent
              width: parent.width - Style.space(16)
              text: modelData.identity || modelData.desktopEntry || "Player"
              textFormat: Text.PlainText
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignHCenter
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: root.fg
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.island.selectPlayer(modelData)
            }
          }
        }

        // Full Music Player Card
        Rectangle {
          visible: root.activePage === "music"
          width: parent.width
          radius: Style.space(16)
          color: root.glass
          border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
          border.width: 1
          implicitHeight: mediaColumn.implicitHeight + Style.space(28)

          ColumnLayout {
            id: mediaColumn
            anchors.fill: parent
            anchors.margins: Style.space(14)
            spacing: Style.space(14)

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(14)

              // Album Art with Rotating Vinyl Backing
              Rectangle {
                Layout.preferredWidth: Style.space(88)
                Layout.preferredHeight: Style.space(88)
                radius: Style.space(14)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
                clip: true

                Image {
                  id: albumArtFull
                  anchors.fill: parent
                  visible: root.island.artUrl !== ""
                  source: visible ? root.island.artUrl : ""
                  sourceSize: Qt.size(240, 240)
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                }

                Rectangle {
                  anchors.centerIn: parent
                  width: Style.space(56)
                  height: Style.space(56)
                  radius: width / 2
                  visible: albumArtFull.status !== Image.Ready
                  color: "#111116"
                  border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                  border.width: 1

                  RotationAnimation on rotation {
                    running: root.island.isPlaying
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 4000
                  }

                  Text {
                    anchors.centerIn: parent
                    text: "♫"
                    color: root.accent
                    font.pixelSize: Style.space(24)
                  }
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.space(4)
                Text {
                  Layout.fillWidth: true
                  text: root.island.hasTrack ? root.island.mediaTitle : "Nothing playing"
                  textFormat: Text.PlainText
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                  color: root.fg
                }
                Text {
                  Layout.fillWidth: true
                  text: root.island.hasTrack
                    ? (root.island.mediaArtist || "Unknown Artist")
                    : "Connect an MPRIS player"
                  textFormat: Text.PlainText
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.64)
                }
                Text {
                  text: root.island.playerName ? ("Source: " + root.island.playerName) : ""
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.space(11)
                  color: root.accent
                }
              }
            }

            // Seek Scrubber
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)
              Rectangle {
                id: seekTrack
                Layout.fillWidth: true
                height: Style.space(6)
                radius: height / 2
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
                Rectangle {
                  width: parent.width * (root.island.duration > 0
                    ? Math.max(0, Math.min(1, root.island.position / root.island.duration)) : 0)
                  height: parent.height
                  radius: height / 2
                  color: root.accent
                  Behavior on width { NumberAnimation { duration: 250 } }
                }
                MouseArea {
                  anchors.fill: parent
                  enabled: root.island.currentPlayer
                    && root.island.currentPlayer.canSeek
                    && root.island.currentPlayer.positionSupported
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) { root.seekFromClick(mouse.x, seekTrack.width) }
                }
              }
              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: root.formatTime(root.island.position)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.6)
                }
                Item { Layout.fillWidth: true }
                Text {
                  text: root.formatTime(root.island.duration)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.6)
                }
              }
            }

            // Media Controls Bar
            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: Style.space(18)
              Repeater {
                model: ["previous", "play-pause", "next"]
                Rectangle {
                  required property string modelData
                  readonly property bool primary: modelData === "play-pause"
                  readonly property var mediaPlayer: root.island.currentPlayer
                  readonly property bool available: mediaPlayer
                    && (modelData === "previous" ? mediaPlayer.canGoPrevious
                      : modelData === "next" ? mediaPlayer.canGoNext : mediaPlayer.canTogglePlaying)
                  Layout.preferredWidth: primary ? Style.space(48) : Style.space(40)
                  Layout.preferredHeight: primary ? Style.space(48) : Style.space(40)
                  radius: width / 2
                  color: !available ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                    : primary ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
                  Text {
                    anchors.centerIn: parent
                    text: modelData === "previous" ? "⏮"
                      : modelData === "next" ? "⏭"
                      : root.island.isPlaying ? "⏸" : "▶"
                    color: parent.available ? (parent.primary ? "#0a0a0e" : root.fg)
                      : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.25)
                    font.pixelSize: parent.primary ? Style.font.body : Style.font.caption
                    font.weight: Font.DemiBold
                  }
                  MouseArea {
                    anchors.fill: parent
                    enabled: parent.available
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.island.mediaAction(parent.modelData)
                  }
                }
              }
            }
          }
        }

        // ================= PAGE: FOCUS STUDIO / TIMER =================
        // Active Countdown Card
        Rectangle {
          visible: root.activePage === "timer" && root.timerTotal > 0
          width: parent.width
          height: Style.space(108)
          radius: Style.space(14)
          color: root.glass
          border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
          border.width: 1

          ColumnLayout {
            anchors.centerIn: parent
            spacing: Style.space(4)
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.timerFinished ? "Session Finished!" : root.timerRunning ? (root.timerName || "Focus in progress") : "Timer Paused"
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.6)
            }
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.formatTime(root.timerLeft)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.space(40)
              font.weight: Font.DemiBold
              color: root.accent
            }
          }
        }

        // Timer Control Buttons
        RowLayout {
          visible: root.activePage === "timer" && root.timerTotal > 0 && !root.timerFinished
          width: parent.width
          spacing: Style.space(8)
          Controls.Button {
            id: pauseTimerButton
            Layout.fillWidth: true
            text: root.timerRunning ? "Pause" : "Resume"
            onClicked: root.toggleTimer()
            background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1) }
            contentItem: Text {
              text: pauseTimerButton.text
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: root.fg
            }
          }
          Controls.Button {
            id: addTimeButton
            Layout.fillWidth: true
            text: "+1 min"
            onClicked: root.adjustTimer(60)
            background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1) }
            contentItem: Text {
              text: addTimeButton.text
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: root.fg
            }
          }
          Controls.Button {
            id: clearTimerButton
            Layout.fillWidth: true
            text: "Clear"
            onClicked: root.clearTimer()
            background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1) }
            contentItem: Text {
              text: clearTimerButton.text
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: root.fg
            }
          }
        }

        // Focus Presets
        Text {
          visible: root.activePage === "timer"
          text: "Presets (" + root.focusSessions + " completed sessions)"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
          color: root.fg
        }

        RowLayout {
          visible: root.activePage === "timer"
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: [
              { minutes: 25, label: "Focus 25m", mode: "focus" },
              { minutes: 50, label: "Deep 50m", mode: "deep" },
              { minutes: 5, label: "Break 5m", mode: "break" },
              { minutes: 15, label: "Long 15m", mode: "break" }
            ]
            Controls.Button {
              id: timerButton
              required property var modelData
              Layout.fillWidth: true
              text: modelData.label
              onClicked: root.startTimer(modelData.minutes,
                sessionNameField.text.trim() || modelData.label, modelData.mode)
              background: Rectangle {
                radius: Style.space(9)
                color: parent.down ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass
                border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
                border.width: 1
              }
              contentItem: Text {
                text: timerButton.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.weight: Font.DemiBold
                color: root.fg
              }
            }
          }
        }

        // Custom Session Name Field
        RowLayout {
          visible: root.activePage === "timer"
          width: parent.width
          spacing: Style.space(8)
          Controls.TextField {
            id: sessionNameField
            Layout.fillWidth: true
            placeholderText: "Session label (e.g. Coding Dynamic Island)"
            text: root.draftSessionName
            onTextEdited: root.draftSessionName = text
            color: root.fg
            placeholderTextColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.42)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            selectByMouse: true
            background: Rectangle {
              radius: Style.space(9)
              color: root.glass
              border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            }
          }
          // Sound Toggle
          Rectangle {
            Layout.preferredWidth: Style.space(38)
            Layout.preferredHeight: Style.space(38)
            radius: Style.space(9)
            color: root.soundEnabled ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.glass
            border.color: root.soundEnabled ? root.accent : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: root.soundEnabled ? "🔔" : "🔕"
              font.pixelSize: Style.font.caption
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.soundEnabled = !root.soundEnabled
                root.persistState()
              }
            }
          }
        }

        // Stopwatch Section
        RowLayout {
          visible: root.activePage === "timer"
          width: parent.width
          Text {
            Layout.fillWidth: true
            text: "Stopwatch"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
            color: root.fg
          }
          Text {
            text: root.formatTime(root.stopwatchElapsed)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.weight: Font.DemiBold
            color: root.accent
          }
        }

        RowLayout {
          visible: root.activePage === "timer"
          width: parent.width
          spacing: Style.space(8)
          Controls.Button {
            Layout.fillWidth: true
            text: root.stopwatchRunning ? "Pause Stopwatch" : "Start Stopwatch"
            onClicked: root.toggleStopwatch()
            background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1) }
            contentItem: Text {
              text: root.stopwatchRunning ? "Pause Stopwatch" : "Start Stopwatch"
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: root.fg
            }
          }
          Controls.Button {
            text: "Reset"
            onClicked: root.resetStopwatch()
            background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1) }
            contentItem: Text {
              text: "Reset"
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              color: root.fg
            }
          }
        }

        // ================= PAGE: AI & MODELS STUDIO =================
        ColumnLayout {
          visible: root.activePage === "agents"
          width: parent.width
          spacing: Style.space(10)

          // Google Antigravity Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(56)
            radius: Style.space(11)
            color: root.glass
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: Style.space(8)
                color: Qt.rgba(0.2, 0.6, 1, 0.18)
                Text { anchors.centerIn: parent; text: "🤖"; font.pixelSize: Style.font.body }
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Google Antigravity"
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  color: root.fg
                }
                Text {
                  text: root.agentsData.antigravity && root.agentsData.antigravity.active
                    ? "Active Session Running" : "Installed & Ready"
                  font.pixelSize: Style.space(10)
                  color: root.agentsData.antigravity && root.agentsData.antigravity.active ? "#34d399" : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
                }
              }
              Rectangle {
                width: Style.space(68)
                height: Style.space(26)
                radius: Style.space(7)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.font.caption; color: root.fg; font.weight: Font.DemiBold }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchTerminal("agy")
                }
              }
            }
          }

          // Claude Code Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(56)
            radius: Style.space(11)
            color: root.glass
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: Style.space(8)
                color: Qt.rgba(0.9, 0.4, 0.2, 0.18)
                Text { anchors.centerIn: parent; text: "⚡"; font.pixelSize: Style.font.body }
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Claude Code"
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  color: root.fg
                }
                Text {
                  text: root.agentsData.claude_code && root.agentsData.claude_code.active
                    ? "Active Session Running" : "Installed & Available"
                  font.pixelSize: Style.space(10)
                  color: root.agentsData.claude_code && root.agentsData.claude_code.active ? "#34d399" : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
                }
              }
              Rectangle {
                width: Style.space(68)
                height: Style.space(26)
                radius: Style.space(7)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.font.caption; color: root.fg; font.weight: Font.DemiBold }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchTerminal("claude")
                }
              }
            }
          }

          // Codex CLI Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(56)
            radius: Style.space(11)
            color: root.glass
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: Style.space(8)
                color: Qt.rgba(0.1, 0.8, 0.5, 0.18)
                Text { anchors.centerIn: parent; text: "💻"; font.pixelSize: Style.font.body }
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Codex CLI"
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  color: root.fg
                }
                Text {
                  text: root.agentsData.codex && root.agentsData.codex.active
                    ? "Active Session Running" : "Installed & Available"
                  font.pixelSize: Style.space(10)
                  color: root.agentsData.codex && root.agentsData.codex.active ? "#34d399" : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
                }
              }
              Rectangle {
                width: Style.space(68)
                height: Style.space(26)
                radius: Style.space(7)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.font.caption; color: root.fg; font.weight: Font.DemiBold }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchTerminal("codex")
                }
              }
            }
          }

          // Local Models (llama-swap / Bonsai 2) Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(62)
            radius: Style.space(11)
            color: root.glass
            border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.1)
            border.width: 1

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(12)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: Style.space(8)
                color: Qt.rgba(0.7, 0.3, 0.9, 0.18)
                Text { anchors.centerIn: parent; text: "🧠"; font.pixelSize: Style.font.body }
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  text: "Local Models (Bonsai 2 / llama-swap)"
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  color: root.fg
                }
                Text {
                  text: root.agentsData.local_models && root.agentsData.local_models.active
                    ? "Online on port 18080 (RTX 4060 GPU)" : "Offline"
                  font.pixelSize: Style.space(10)
                  color: root.agentsData.local_models && root.agentsData.local_models.active ? "#34d399" : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.5)
                }
              }
              Rectangle {
                width: Style.space(68)
                height: Style.space(26)
                radius: Style.space(7)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                Text { anchors.centerIn: parent; text: "Status"; font.pixelSize: Style.font.caption; color: root.fg; font.weight: Font.DemiBold }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchTerminal("curl -s http://127.0.0.1:18080/v1/models | jq .")
                }
              }
            }
          }
        }

        // ================= PAGE: DESK =================
        DeskPage {
          owner: root
          visible: root.activePage === "desk"
          width: parent.width
        }
      }
    }
  }
}
