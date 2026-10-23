import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  // Master expansion state
  property bool isExpanded: false
  property string activeTab: "music"

  // Shell & Telemetry
  readonly property string scriptPath:
    Qt.resolvedUrl("island-backend.sh").toString().replace(/^file:\/\//, "")
  readonly property var mediaPlayers: Mpris.players.values
  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  readonly property int workspaceId: focusedWorkspace ? focusedWorkspace.id : 0
  readonly property int workspaceWindows: focusedWorkspace
    ? focusedWorkspace.toplevels.values.length : 0
  readonly property var currentWindows: focusedWorkspace ? focusedWorkspace.toplevels.values : []
  readonly property var focusedWindow: Hyprland.activeToplevel

  // Liquid Glass Palette
  readonly property color capsuleSurface: "#07070a"
  readonly property color capsuleInk: "#f8f9fa"
  readonly property color accent: Commons.Color.accent
  readonly property color glass: Qt.rgba(capsuleInk.r, capsuleInk.g, capsuleInk.b, 0.055)

  // Media
  readonly property var currentPlayer: root.resolvePlayer()
  readonly property bool hasTrack: currentPlayer !== null && currentPlayer.trackTitle.length > 0
  readonly property bool isPlaying: currentPlayer !== null && currentPlayer.isPlaying
  readonly property string mediaTitle: currentPlayer ? currentPlayer.trackTitle : ""
  readonly property string mediaArtist: currentPlayer ? currentPlayer.trackArtist : ""
  readonly property string artUrl: currentPlayer ? root.cleanArtUrl(currentPlayer.trackArtUrl) : ""
  readonly property int position: currentPlayer ? Math.floor(currentPlayer.position) : 0
  readonly property int duration: currentPlayer && currentPlayer.lengthSupported
    ? Math.floor(currentPlayer.length) : 0
  readonly property string playerName: currentPlayer
    ? (currentPlayer.identity || currentPlayer.desktopEntry || "Media Player") : ""

  property var selectedPlayer: null
  property bool capsuleHovered: false

  // Telemetry
  property int batteryPct: -1
  property string batteryStatus: "Unavailable"
  property bool batteryAvailable: false
  property bool isRecording: false
  property var agentsData: ({})
  property string clockLabel: Qt.formatTime(new Date(), "h:mm AP")

  // Volume HUD
  property int volumeHudLevel: -1
  property bool showVolumeHud: false

  // Focus Studio & Timer
  property int timerTotal: 0
  property int timerLeft: 0
  property double timerDeadline: 0
  property bool timerRunning: false
  property bool timerFinished: false
  property string timerName: ""
  property string timerMode: "focus"
  property int focusSessions: 0
  property string draftSessionName: ""
  property bool soundEnabled: true

  readonly property bool timerActive: timerTotal > 0 && !timerFinished
  readonly property bool stopwatchVisible: stopwatchRunning || stopwatchElapsed > 0

  // Stopwatch
  property int stopwatchElapsed: 0
  property int stopwatchBaseSeconds: 0
  property double stopwatchStartedAt: 0
  property bool stopwatchRunning: false

  // State persistence
  property bool stateReady: false
  property bool stateTouched: false

  // Bounding rect for input masking in Service.qml
  readonly property var maskItem: morphCard
  readonly property var satelliteItem: timerSatellite

  // Compact width calculation
  readonly property real compactWidth: {
    if (showVolumeHud) return Style.space(165)
    if (hasTrack) {
      return Math.min(Style.space(340), Style.space(120)
        + Math.max(miniTitle.implicitWidth, miniArtist.implicitWidth)
        + (capsuleHovered ? Style.space(50) : Style.space(10)))
    }
    if (timerActive) return Style.space(170)
    // Idle state
    return capsuleHovered ? Style.space(185) : Style.space(155)
  }

  function cleanArtUrl(raw) {
    if (!raw || typeof raw !== "string") return ""
    var trimmed = raw.trim()
    if (trimmed === "") return ""
    if (trimmed.startsWith("file://") || trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
    if (trimmed.startsWith("/")) return "file://" + trimmed
    return ""
  }

  function resolvePlayer() {
    var players = root.mediaPlayers
    if (root.selectedPlayer && players.indexOf(root.selectedPlayer) >= 0)
      return root.selectedPlayer
    for (var i = 0; i < players.length; ++i)
      if (players[i].isPlaying) return players[i]
    for (var j = 0; j < players.length; ++j)
      if (players[j].trackTitle) return players[j]
    return players.length ? players[0] : null
  }

  function selectPlayer(player) { selectedPlayer = player }

  function cyclePlayer() {
    var players = root.mediaPlayers
    if (players.length < 2) return
    var idx = players.indexOf(root.currentPlayer)
    var next = (idx + 1) % players.length
    root.selectedPlayer = players[next]
  }

  function mediaAction(action, value) {
    var player = root.currentPlayer
    if (!player) return
    if (action === "play-pause" && player.canTogglePlaying) {
      player.togglePlaying()
    } else if (action === "previous" && player.canGoPrevious) {
      player.previous()
    } else if (action === "next" && player.canGoNext) {
      player.next()
    } else if (action === "seek" && player.canSeek && player.positionSupported) {
      player.position = Math.max(0, Math.min(player.length, Number(value) || 0))
    } else if ((action === "volume-up" || action === "volume-down")
      && player.canControl && player.volumeSupported) {
      var step = action === "volume-up" ? 0.05 : -0.05
      var newVol = Math.max(0, Math.min(1, player.volume + step))
      player.volume = newVol
      root.volumeHudLevel = Math.round(newVol * 100)
      root.showVolumeHud = true
      volumeHudTimer.restart()
    }
  }

  Timer {
    id: volumeHudTimer
    interval: 1300
    onTriggered: root.showVolumeHud = false
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
          timerName || "Focus Complete",
          "Focus session " + focusSessions + " finished. Take a well-deserved break!"])
      }
    }
    updateStopwatch()
  }

  function startTimer(minutes, name, mode) {
    timerTotal = minutes * 60
    timerLeft = timerTotal
    timerName = name || "Focus session"
    timerMode = mode || "focus"
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

  function persistState() {
    stateTouched = true
    if (!stateReady) return
    stateFile.setText(JSON.stringify({
      version: 4,
      timerTotal: timerTotal,
      timerLeft: timerLeft,
      timerDeadline: timerDeadline,
      timerRunning: timerRunning,
      timerFinished: timerFinished,
      timerName: timerName,
      timerMode: timerMode,
      focusSessions: focusSessions,
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
      timerTotal = Math.max(0, Number(saved.timerTotal) || 0)
      timerLeft = Math.max(0, Number(saved.timerLeft) || 0)
      timerDeadline = Number(saved.timerDeadline) || 0
      timerFinished = saved.timerFinished === true
      timerName = typeof saved.timerName === "string" ? saved.timerName : ""
      timerMode = typeof saved.timerMode === "string" ? saved.timerMode : "focus"
      focusSessions = Math.max(0, Number(saved.focusSessions) || 0)
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

  function refreshTelemetry() {
    if (telemetryProc.running) return
    telemetryProc.command = ["bash", scriptPath, "get"]
    telemetryProc.running = true
  }

  function launchTerminal(cmd) {
    if (cmd) Quickshell.execDetached(["foot", "-e", "bash", "-c", cmd + "; exec bash"])
    else Quickshell.execDetached(["foot"])
    root.isExpanded = false
  }

  function nextOmarchyBackground() {
    Quickshell.execDetached(["omarchy", "theme", "bg", "next"])
  }

  function openOmarchyThemeSwitcher() {
    Quickshell.execDetached(["omarchy", "theme", "switcher"])
    root.isExpanded = false
  }

  function takeScreenshot() {
    Quickshell.execDetached(["omarchy-capture-screenshot"])
    root.isExpanded = false
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
    interval: 1000
    repeat: true
    running: root.timerRunning || root.stopwatchRunning
    onTriggered: root.updateActivities()
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: root.refreshTelemetry()
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    onTriggered: root.clockLabel = Qt.formatTime(new Date(), "h:mm AP")
  }

  Process {
    id: telemetryProc
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.battery) {
            root.batteryAvailable = data.battery.available === true
            root.batteryPct = data.battery.pct === null ? -1 : Number(data.battery.pct)
            root.batteryStatus = data.battery.status || "Unavailable"
          }
          if (data.recording) {
            root.isRecording = data.recording.active === true
          }
          if (data.agents) {
            root.agentsData = data.agents
          }
        } catch (e) {}
      }
    }
  }

  Component.onCompleted: {
    root.refreshTelemetry()
    root.restoreState()
  }

  // ================= VISUAL STRUCTURE =================
  Item {
    id: container
    anchors.fill: parent

    // Dismiss Area on Outside Click (When Expanded)
    MouseArea {
      anchors.fill: parent
      visible: root.isExpanded
      z: 0
      onClicked: root.isExpanded = false
    }

    // Ambient Halo Backlight (Breathes when music plays)
    Rectangle {
      id: ambientHalo
      z: 1
      anchors.centerIn: morphCard
      width: morphCard.width + Style.space(26)
      height: morphCard.height + Style.space(26)
      radius: morphCard.radius + Style.space(12)
      color: root.isPlaying
        ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.28)
        : "transparent"
      opacity: root.isPlaying ? 1 : 0
      visible: opacity > 0.01

      Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuad } }
      Behavior on width { SpringAnimation { spring: 4.8; damping: 0.32; mass: 0.8 } }
      Behavior on height { SpringAnimation { spring: 4.8; damping: 0.32; mass: 0.8 } }
      Behavior on radius { NumberAnimation { duration: 240 } }
    }

    // THE MORPHING ISLAND CARD
    Rectangle {
      id: morphCard
      z: 2
      anchors.horizontalCenter: parent.horizontalCenter
      y: Style.space(8)

      width: root.isExpanded ? Style.space(480) : root.compactWidth
      height: root.isExpanded ? Style.space(460) : Style.space(34)
      radius: root.isExpanded ? Style.space(26) : Style.space(17)

      gradient: Gradient {
        GradientStop { position: 0.0; color: "#1c1c20" }
        GradientStop { position: 0.28; color: "#09090c" }
        GradientStop { position: 1.0; color: "#030305" }
      }

      border.color: root.isExpanded
        ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.55)
        : (root.capsuleHovered ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.12))
      border.width: 1
      clip: true

      Behavior on width { SpringAnimation { spring: 4.8; damping: 0.32; mass: 0.8 } }
      Behavior on height { SpringAnimation { spring: 4.8; damping: 0.32; mass: 0.8 } }
      Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
      Behavior on border.color { ColorAnimation { duration: 180 } }

      // Physical Specular Sheen (Curved Glass Edge)
      Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1.2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - Style.space(32))
        height: 1.2
        radius: 0.6
        color: root.capsuleInk
        opacity: root.isExpanded ? 0.35 : (root.capsuleHovered ? 0.28 : 0.16)
        Behavior on opacity { NumberAnimation { duration: 180 } }
      }

      // Compact Click & Hover Area
      MouseArea {
        id: compactMouse
        anchors.fill: parent
        enabled: !root.isExpanded
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.button === Qt.MiddleButton) {
            root.mediaAction("play-pause")
          } else if (mouse.button === Qt.RightButton) {
            root.cyclePlayer()
          } else {
            root.isExpanded = true
          }
        }
        onWheel: function(wheel) {
          root.mediaAction(wheel.angleDelta.y > 0 ? "volume-up" : "volume-down")
        }
      }

      HoverHandler {
        onHoveredChanged: root.capsuleHovered = hovered
      }

      // -------------------------------------------------------------
      // COMPACT VIEW CONTENT (Visible when NOT expanded)
      // -------------------------------------------------------------
      Item {
        anchors.fill: parent
        visible: !root.isExpanded
        opacity: !root.isExpanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        // Volume HUD
        RowLayout {
          anchors.centerIn: parent
          spacing: Style.space(8)
          visible: root.showVolumeHud

          Text {
            text: root.volumeHudLevel === 0 ? "🔇" : root.volumeHudLevel < 50 ? "🔉" : "🔊"
            font.pixelSize: Style.font.body
            color: root.accent
          }
          Rectangle {
            Layout.preferredWidth: Style.space(78)
            Layout.preferredHeight: Style.space(4)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.18)
            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, root.volumeHudLevel / 100))
              height: parent.height
              radius: height / 2
              color: root.accent
            }
          }
          Text {
            text: root.volumeHudLevel + "%"
            color: root.capsuleInk
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
          }
        }

        // 1. Music Playing Mode
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)
          visible: !root.showVolumeHud && root.hasTrack

          // Leading: Square Album Art / Rotating Vinyl
          Rectangle {
            Layout.preferredWidth: Style.space(24)
            Layout.preferredHeight: Style.space(24)
            radius: Style.space(7)
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
            clip: true

            Image {
              id: miniArt
              anchors.fill: parent
              visible: root.artUrl !== "" && status !== Image.Error
              source: visible ? root.artUrl : ""
              sourceSize: Qt.size(96, 96)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }

            Rectangle {
              anchors.centerIn: parent
              width: Style.space(20)
              height: Style.space(20)
              radius: width / 2
              visible: !miniArt.visible
              color: "#111116"
              border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
              border.width: 1

              RotationAnimation on rotation {
                running: root.isPlaying
                loops: Animation.Infinite
                from: 0; to: 360; duration: 4000
              }
              Rectangle {
                anchors.centerIn: parent
                width: Style.space(6); height: Style.space(6); radius: width / 2
                color: root.accent
              }
            }
          }

          // Center: Track Title & Artist
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              id: miniTitle
              Layout.fillWidth: true
              text: root.mediaTitle
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
              color: root.capsuleInk
            }
            Text {
              id: miniArtist
              Layout.fillWidth: true
              text: root.mediaArtist || root.playerName
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.space(9)
              color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.65)
            }
          }

          // Trailing: 4-Bar Dancing Equalizer Waves
          Row {
            spacing: Style.space(2)
            visible: root.isPlaying
            Layout.alignment: Qt.AlignVCenter
            Repeater {
              model: [
                { minH: 3, maxH: 12, dur1: 320, dur2: 380 },
                { minH: 4, maxH: 15, dur1: 420, dur2: 310 },
                { minH: 3, maxH: 11, dur1: 290, dur2: 360 },
                { minH: 4, maxH: 14, dur1: 440, dur2: 410 }
              ]
              Rectangle {
                required property var modelData
                width: Style.space(2.4)
                height: root.isPlaying ? modelData.maxH : modelData.minH
                radius: Style.space(1.2)
                color: root.accent

                SequentialAnimation on height {
                  running: root.isPlaying
                  loops: Animation.Infinite
                  NumberAnimation { to: modelData.minH; duration: modelData.dur1; easing.type: Easing.InOutQuad }
                  NumberAnimation { to: modelData.maxH; duration: modelData.dur2; easing.type: Easing.InOutQuad }
                }
              }
            }
          }

          Text {
            visible: !root.isPlaying
            text: "Ⅱ"
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5)
          }
        }

        // 2. Timer Only Mode (When no track is playing)
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(8)
          visible: !root.showVolumeHud && !root.hasTrack && root.timerActive

          Text { text: "⏱️"; font.pixelSize: Style.font.body }
          Text {
            Layout.fillWidth: true
            text: root.formatTime(root.timerLeft)
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }
          Rectangle {
            width: Style.space(6); height: Style.space(6); radius: width / 2
            color: root.timerRunning ? root.accent : "#f59e0b"
          }
        }

        // 3. Resting Idle Mode (Clock & Battery)
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(8)
          visible: !root.showVolumeHud && !root.hasTrack && !root.timerActive

          Text {
            id: clockDisplay
            Layout.fillWidth: true
            text: root.clockLabel
            font.family: Style.font.family
            font.pixelSize: Style.space(12)
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }

          Text {
            text: "•"
            font.pixelSize: Style.space(11)
            color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.4)
          }

          Row {
            spacing: Style.space(4)
            Text {
              text: root.batteryPct <= 20 ? "🪫" : "🔋"
              font.pixelSize: Style.font.caption
            }
            Text {
              text: root.batteryAvailable ? root.batteryPct + "%" : "Ready"
              font.family: Style.font.family
              font.pixelSize: Style.space(11)
              font.weight: Font.Medium
              color: root.capsuleInk
            }
          }
        }
      }

      // -------------------------------------------------------------
      // EXPANDED VIEW CONTENT (Full Rich Card)
      // -------------------------------------------------------------
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(12)
        visible: root.isExpanded
        opacity: root.isExpanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Top Navigation Header (Capsule handle + Tabs)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Capsule Morph Handle (Click to Collapse)
          Rectangle {
            Layout.preferredWidth: Style.space(36)
            Layout.preferredHeight: Style.space(30)
            radius: Style.space(9)
            color: Qt.rgba(1, 1, 1, 0.08)
            Text {
              anchors.centerIn: parent
              text: "✕"
              font.pixelSize: Style.space(13)
              color: root.capsuleInk
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.isExpanded = false
            }
          }

          // Tabs
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            Repeater {
              model: [
                { key: "music", label: "Music", icon: "♫" },
                { key: "timer", label: "Focus", icon: "⏱️" },
                { key: "agents", label: "AI Studio", icon: "🤖" },
                { key: "desk", label: "Desk", icon: "🖥️" }
              ]
              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                height: Style.space(30)
                radius: Style.space(8)
                color: root.activeTab === modelData.key ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : root.glass
                border.color: root.activeTab === modelData.key ? root.accent : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(5)
                  Text {
                    text: modelData.icon
                    font.pixelSize: Style.font.caption
                  }
                  Text {
                    text: modelData.label
                    color: root.activeTab === parent.parent.modelData.key ? root.capsuleInk : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6)
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.weight: root.activeTab === parent.parent.modelData.key ? Font.DemiBold : Font.Normal
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = parent.modelData.key
                }
              }
            }
          }
        }

        // ================= TAB: MUSIC =================
        ColumnLayout {
          visible: root.activeTab === "music"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(14)

          // Album Artwork & Track Info
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(14)

            Rectangle {
              Layout.preferredWidth: Style.space(100)
              Layout.preferredHeight: Style.space(100)
              radius: Style.space(16)
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
              clip: true

              Image {
                id: bigArt
                anchors.fill: parent
                visible: root.artUrl !== "" && status !== Image.Error
                source: visible ? root.artUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }

              Rectangle {
                anchors.centerIn: parent
                width: Style.space(64)
                height: Style.space(64)
                radius: width / 2
                visible: !bigArt.visible
                color: "#111116"
                border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.5)
                border.width: 1

                RotationAnimation on rotation {
                  running: root.isPlaying
                  loops: Animation.Infinite
                  from: 0; to: 360; duration: 4000
                }
                Text {
                  anchors.centerIn: parent
                  text: "♫"
                  color: root.accent
                  font.pixelSize: Style.space(26)
                }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)
              Text {
                Layout.fillWidth: true
                text: root.hasTrack ? root.mediaTitle : "Nothing playing"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                color: root.capsuleInk
              }
              Text {
                Layout.fillWidth: true
                text: root.hasTrack ? (root.mediaArtist || "Unknown Artist") : "Start music in any player"
                textFormat: Text.PlainText
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.65)
              }
              Text {
                text: root.playerName ? ("Source: " + root.playerName) : ""
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                color: root.accent
              }
            }
          }

          // Interactive Seek Progress Bar
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)
            Rectangle {
              id: expandedSeek
              Layout.fillWidth: true
              height: Style.space(6)
              radius: height / 2
              color: Qt.rgba(1, 1, 1, 0.16)
              Rectangle {
                width: parent.width * (root.duration > 0
                  ? Math.max(0, Math.min(1, root.position / root.duration)) : 0)
                height: parent.height
                radius: height / 2
                color: root.accent
                Behavior on width { NumberAnimation { duration: 250 } }
              }
              MouseArea {
                anchors.fill: parent
                enabled: root.currentPlayer && root.currentPlayer.canSeek && root.currentPlayer.positionSupported
                cursorShape: Qt.PointingHandCursor
                onClicked: function(mouse) {
                  if (root.duration <= 0 || width <= 0) return
                  var sec = Math.max(0, Math.min(root.duration, Math.round(root.duration * mouse.x / width)))
                  root.mediaAction("seek", sec)
                }
              }
            }
            RowLayout {
              Layout.fillWidth: true
              Text {
                text: root.formatTime(root.position)
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.55)
              }
              Item { Layout.fillWidth: true }
              Text {
                text: root.formatTime(root.duration)
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.55)
              }
            }
          }

          // Main Media Controls
          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Style.space(24)
            Repeater {
              model: ["previous", "play-pause", "next"]
              Rectangle {
                required property string modelData
                readonly property bool primary: modelData === "play-pause"
                readonly property var p: root.currentPlayer
                readonly property bool available: p && (modelData === "previous" ? p.canGoPrevious
                  : modelData === "next" ? p.canGoNext : p.canTogglePlaying)

                Layout.preferredWidth: primary ? Style.space(52) : Style.space(42)
                Layout.preferredHeight: primary ? Style.space(52) : Style.space(42)
                radius: width / 2
                color: !available ? Qt.rgba(1, 1, 1, 0.04)
                  : primary ? root.accent : Qt.rgba(1, 1, 1, 0.1)

                Text {
                  anchors.centerIn: parent
                  text: modelData === "previous" ? "⏮" : modelData === "next" ? "⏭" : root.isPlaying ? "⏸" : "▶"
                  color: parent.available ? (parent.primary ? "#08080a" : root.capsuleInk) : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.25)
                  font.pixelSize: parent.primary ? Style.font.title : Style.font.body
                  font.weight: Font.DemiBold
                }
                MouseArea {
                  anchors.fill: parent
                  enabled: parent.available
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.mediaAction(parent.modelData)
                }
              }
            }
          }

          // Multi-Player Selector Chips
          ListView {
            Layout.fillWidth: true
            height: Style.space(32)
            orientation: ListView.Horizontal
            spacing: Style.space(6)
            clip: true
            model: Mpris.players

            header: Rectangle {
              width: Style.space(52)
              height: Style.space(28)
              radius: height / 2
              color: root.selectedPlayer === null ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24) : root.glass
              border.color: root.selectedPlayer === null ? root.accent : Qt.rgba(1, 1, 1, 0.1)
              Text {
                anchors.centerIn: parent
                text: "Auto"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: root.capsuleInk
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectPlayer(null)
              }
            }

            delegate: Rectangle {
              required property var modelData
              width: Math.min(Style.space(145), playerChipText.implicitWidth + Style.space(24))
              height: Style.space(28)
              radius: height / 2
              color: root.currentPlayer === modelData ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.24) : root.glass
              border.color: root.currentPlayer === modelData ? root.accent : Qt.rgba(1, 1, 1, 0.1)
              Text {
                id: playerChipText
                anchors.centerIn: parent
                width: parent.width - Style.space(16)
                text: modelData.identity || modelData.desktopEntry || "Player"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: root.capsuleInk
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectPlayer(modelData)
              }
            }
          }
        }

        // ================= TAB: FOCUS STUDIO =================
        ColumnLayout {
          visible: root.activeTab === "timer"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(12)

          // Big Timer Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(100)
            radius: Style.space(16)
            color: root.glass
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
            border.width: 1

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 2
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.timerFinished ? "Session Finished!" : root.timerRunning ? (root.timerName || "Focus Countdown") : "Timer Paused"
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6)
              }
              Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.formatTime(root.timerLeft)
                font.family: Style.font.family
                font.pixelSize: Style.space(38)
                font.weight: Font.DemiBold
                color: root.accent
              }
            }
          }

          // Timer Controls
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Controls.Button {
              Layout.fillWidth: true
              text: root.timerRunning ? "Pause" : "Resume"
              onClicked: root.toggleTimer()
              background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "+1 min"
              onClicked: root.adjustTimer(60)
              background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "Clear"
              onClicked: root.clearTimer()
              background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
            }
          }

          // Presets
          Text {
            text: "Presets (" + root.focusSessions + " completed sessions)"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Repeater {
              model: [
                { minutes: 25, label: "Focus 25m", mode: "focus" },
                { minutes: 50, label: "Deep 50m", mode: "deep" },
                { minutes: 5, label: "Break 5m", mode: "break" },
                { minutes: 15, label: "Long 15m", mode: "break" }
              ]
              Controls.Button {
                id: tPresetBtn
                required property var modelData
                Layout.fillWidth: true
                text: modelData.label
                onClicked: root.startTimer(modelData.minutes, sessionNameField.text.trim() || modelData.label, modelData.mode)
                background: Rectangle {
                  radius: Style.space(9)
                  color: parent.down ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass
                  border.color: Qt.rgba(1, 1, 1, 0.1)
                }
                contentItem: Text {
                  text: tPresetBtn.text
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  color: root.capsuleInk
                }
              }
            }
          }

          // Custom Session Label & Chime Toggle
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Controls.TextField {
              id: sessionNameField
              Layout.fillWidth: true
              placeholderText: "Session label (optional)"
              text: root.draftSessionName
              onTextEdited: root.draftSessionName = text
              color: root.capsuleInk
              placeholderTextColor: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.42)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              selectByMouse: true
              background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
            }
            Rectangle {
              Layout.preferredWidth: Style.space(36)
              Layout.preferredHeight: Style.space(36)
              radius: Style.space(9)
              color: root.soundEnabled ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.glass
              border.color: root.soundEnabled ? root.accent : Qt.rgba(1, 1, 1, 0.1)
              Text { anchors.centerIn: parent; text: root.soundEnabled ? "🔔" : "🔕"; font.pixelSize: Style.font.caption }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.soundEnabled = !root.soundEnabled; root.persistState() }
              }
            }
          }

          // Stopwatch Row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)
            Controls.Button {
              Layout.fillWidth: true
              text: root.stopwatchRunning ? "Pause Stopwatch" : "Start Stopwatch (" + root.formatTime(root.stopwatchElapsed) + ")"
              onClicked: root.toggleStopwatch()
              background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
            }
            Controls.Button {
              text: "Reset"
              onClicked: root.resetStopwatch()
              background: Rectangle { radius: Style.space(9); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: "Reset"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
            }
          }
        }

        // ================= TAB: AI AGENTS & MODELS =================
        ColumnLayout {
          visible: root.activeTab === "agents"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

          // Google Antigravity Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(54)
            radius: Style.space(11)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)
            RowLayout {
              anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(10)
              Rectangle { width: Style.space(32); height: Style.space(32); radius: Style.space(8); color: Qt.rgba(0.2, 0.6, 1, 0.18)
                Text { anchors.centerIn: parent; text: "🤖"; font.pixelSize: Style.font.body } }
              ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: "Google Antigravity"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                Text { text: root.agentsData.antigravity && root.agentsData.antigravity.active ? "Active Session Running" : "Installed & Available"; font.pixelSize: Style.space(10); color: root.agentsData.antigravity && root.agentsData.antigravity.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
              Rectangle { width: Style.space(68); height: Style.space(26); radius: Style.space(7); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.font.caption; color: root.capsuleInk; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("agy") } }
            }
          }

          // Claude Code Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(54)
            radius: Style.space(11)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)
            RowLayout {
              anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(10)
              Rectangle { width: Style.space(32); height: Style.space(32); radius: Style.space(8); color: Qt.rgba(0.9, 0.4, 0.2, 0.18)
                Text { anchors.centerIn: parent; text: "⚡"; font.pixelSize: Style.font.body } }
              ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: "Claude Code"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                Text { text: root.agentsData.claude_code && root.agentsData.claude_code.active ? "Active Session Running" : "Installed & Available"; font.pixelSize: Style.space(10); color: root.agentsData.claude_code && root.agentsData.claude_code.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
              Rectangle { width: Style.space(68); height: Style.space(26); radius: Style.space(7); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.font.caption; color: root.capsuleInk; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("claude") } }
            }
          }

          // Codex CLI Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(54)
            radius: Style.space(11)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)
            RowLayout {
              anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(10)
              Rectangle { width: Style.space(32); height: Style.space(32); radius: Style.space(8); color: Qt.rgba(0.1, 0.8, 0.5, 0.18)
                Text { anchors.centerIn: parent; text: "💻"; font.pixelSize: Style.font.body } }
              ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: "Codex CLI"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                Text { text: root.agentsData.codex && root.agentsData.codex.active ? "Active Session Running" : "Installed & Available"; font.pixelSize: Style.space(10); color: root.agentsData.codex && root.agentsData.codex.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
              Rectangle { width: Style.space(68); height: Style.space(26); radius: Style.space(7); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.font.caption; color: root.capsuleInk; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("codex") } }
            }
          }

          // Local Models Card (Bonsai 2 / llama-swap)
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(58)
            radius: Style.space(11)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)
            RowLayout {
              anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(10)
              Rectangle { width: Style.space(32); height: Style.space(32); radius: Style.space(8); color: Qt.rgba(0.7, 0.3, 0.9, 0.18)
                Text { anchors.centerIn: parent; text: "🧠"; font.pixelSize: Style.font.body } }
              ColumnLayout { Layout.fillWidth: true; spacing: 1
                Text { text: "Local Models (Bonsai 2 / llama-swap)"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                Text { text: "Online: 127.0.0.1:18080 (RTX 4060 GPU)"; font.pixelSize: Style.space(10); color: "#34d399" } }
              Rectangle { width: Style.space(68); height: Style.space(26); radius: Style.space(7); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                Text { anchors.centerIn: parent; text: "Models"; font.pixelSize: Style.font.caption; color: root.capsuleInk; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("curl -s http://127.0.0.1:18080/v1/models | jq .") } }
            }
          }
        }

        // ================= TAB: HYPRLAND DESK =================
        ColumnLayout {
          visible: root.activeTab === "desk"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

          // Workspaces Row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Repeater {
              model: Hyprland.workspaces.values
              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                height: Style.space(38)
                radius: Style.space(9)
                color: modelData.focused ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass
                border.color: modelData.focused ? root.accent : Qt.rgba(1, 1, 1, 0.1)
                Column {
                  anchors.centerIn: parent; spacing: 1
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.name || String(parent.parent.modelData.id); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: (parent.parent.modelData.toplevels ? parent.parent.modelData.toplevels.values.length : 0) + " win"; font.pixelSize: Style.space(9); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { parent.modelData.activate(); root.isExpanded = false } }
              }
            }
          }

          // Open Windows on Workspace
          Text { text: "Open Windows"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
          ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(5)
            model: root.currentWindows
            delegate: Rectangle {
              required property var modelData
              width: parent ? parent.width : 0
              height: Style.space(40)
              radius: Style.space(8)
              color: modelData.activated ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : root.glass
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(8)
                Rectangle { width: 6; height: 6; radius: 3; color: parent.parent.modelData.activated ? root.accent : Qt.rgba(1, 1, 1, 0.3) }
                Text { Layout.fillWidth: true; text: parent.parent.modelData.title || "Window"; font.family: Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; color: root.capsuleInk }
                Text { text: "↗"; font.pixelSize: Style.font.body; color: root.accent }
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (typeof modelData.activate === "function") modelData.activate()
                  else if (modelData.handle) modelData.handle.activate()
                  root.isExpanded = false
                }
              }
            }
          }

          // Quick System Bar
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Controls.Button {
              Layout.fillWidth: true
              text: "▧ Wallpaper"
              onClicked: root.nextOmarchyBackground()
              background: Rectangle { radius: Style.space(8); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "◐ Theme"
              onClicked: root.openOmarchyThemeSwitcher()
              background: Rectangle { radius: Style.space(8); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "📸 Shot"
              onClicked: root.takeScreenshot()
              background: Rectangle { radius: Style.space(8); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
            }
          }
        }
      }
    }

    // SPLIT SATELLITE BUBBLE (Timer / Stopwatch active while music plays)
    Rectangle {
      id: timerSatellite
      z: 2
      visible: !root.isExpanded && root.hasTrack && (root.timerActive || root.stopwatchVisible)
      anchors.left: morphCard.right
      anchors.leftMargin: Style.space(6)
      y: Style.space(8)
      width: Style.space(78)
      height: Style.space(34)
      radius: height / 2

      gradient: Gradient {
        GradientStop { position: 0.0; color: "#1c1c20" }
        GradientStop { position: 0.28; color: "#09090c" }
        GradientStop { position: 1.0; color: "#030305" }
      }
      border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
      border.width: 1

      Row {
        anchors.centerIn: parent
        spacing: Style.space(4)
        Text {
          text: root.timerActive ? "⏱️" : "⏱"
          font.pixelSize: Style.space(10)
        }
        Text {
          text: root.timerActive ? root.formatTime(root.timerLeft) : root.formatTime(root.stopwatchElapsed)
          font.family: Style.font.family
          font.pixelSize: Style.space(11)
          font.weight: Font.DemiBold
          color: root.capsuleInk
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.activeTab = "timer"
          root.isExpanded = true
        }
      }
    }
  }
}
