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

  // Master States
  property bool isExpanded: false
  property bool isPeeking: false
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
  property string lastTrackSeen: ""

  // Telemetry
  property int batteryPct: -1
  property string batteryStatus: "Unavailable"
  property bool batteryAvailable: false
  property string lastBatteryStatusSeen: ""
  property bool isRecording: false
  property var agentsData: ({})
  property var localModelsList: []
  property var clipboardData: ({ type: "empty", text: "", image_path: "" })
  property string clockLabel: Qt.formatTime(new Date(), "h:mm AP")

  // System Controls
  property int systemVolume: 50
  property bool systemMuted: false
  property int systemBrightness: 50
  property bool nightlightEnabled: false
  property bool idleEnabled: false

  // Volume HUD on scroll
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
  property string scratchpadText: ""

  readonly property bool timerActive: timerTotal > 0 && !timerFinished
  readonly property bool stopwatchVisible: stopwatchRunning || stopwatchElapsed > 0

  // Stopwatch
  property int stopwatchElapsed: 0
  property int stopwatchBaseSeconds: 0
  property double stopwatchStartedAt: 0
  property bool stopwatchRunning: false

  // Motion physics (Shake & Dip)
  property real shakeX: 0
  property real bounceY: 0

  // Peek Banners
  property var peekData: ({ icon: "music", title: "", subtitle: "", target: "music" })

  // State persistence
  property bool stateReady: false
  property bool stateTouched: false

  // Bounding rect for input masking in Service.qml
  readonly property var maskItem: morphCard
  readonly property var satelliteItem: timerSatellite

  // Peek Width calculation
  readonly property real peekWidth: {
    var titleLen = (root.peekData.title || "").length
    var subLen = (root.peekData.subtitle || "").length
    var maxLen = Math.max(titleLen, subLen)
    return Math.min(Style.space(430), Math.max(Style.space(270), Style.space(90) + maxLen * Style.space(7.2)))
  }

  // Compact width calculation
  readonly property real compactWidth: {
    if (showVolumeHud) return Style.space(170)
    if (hasTrack) {
      return Math.min(Style.space(350), Style.space(120)
        + Math.max(miniTitle.implicitWidth, miniArtist.implicitWidth)
        + (capsuleHovered ? Style.space(50) : Style.space(12)))
    }
    if (timerActive) return Style.space(175)
    // Idle state
    return capsuleHovered ? Style.space(190) : Style.space(160)
  }

  // ================= CAVA REAL-TIME AUDIO VISUALIZER =================
  Item {
    id: cavaVisualizer
    property bool active: root.isPlaying
    property real level: 0.0
    property real beat: 0.0
    property real peak: 0.3
    property var bars: [0.15, 0.25, 0.2, 0.18]

    readonly property string configPath:
      (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dynamic-island-pro-cava.conf"

    Process {
      id: cavaProc
      running: cavaVisualizer.active
      command: ["sh", "-c",
        "mkdir -p \"$(dirname \"$1\")\"; cat > \"$1\" <<'CONF'\n" +
        "[general]\nbars = 8\nframerate = 30\nautosens = 1\nlower_cutoff_freq = 50\nhigher_cutoff_freq = 10000\n" +
        "[input]\nmethod = pipewire\nsource = auto\n" +
        "[output]\nchannels = mono\nmono_option = average\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\n" +
        "[smoothing]\nnoise_reduction = 45\nCONF\n" +
        "exec cava -p \"$1\"", "sh", cavaVisualizer.configPath]

      stdout: SplitParser {
        onRead: function(line) {
          cavaVisualizer.processLine(line)
        }
      }

      onRunningChanged: {
        if (!running) {
          cavaVisualizer.level = 0
          cavaVisualizer.beat = 0
          cavaVisualizer.bars = [0.15, 0.25, 0.2, 0.18]
        }
      }
    }

    function processLine(line) {
      if (!line) return
      var parts = line.split(";")
      var raw = []
      for (var i = 0; i < parts.length; i++) {
        if (parts[i] === "") continue
        raw.push(Math.min(1.0, Math.max(0.0, Number(parts[i]) / 100.0)))
      }
      if (raw.length < 4) return
      var b0 = raw[0] || 0
      var b1 = raw[1] || 0
      var b2 = raw[2] || 0
      var b3 = raw[3] || 0
      bars = [b0, b1, b2, b3]
      var avg = (b0 + b1 + b2 + b3) / 4.0
      peak = Math.max(avg, peak * 0.995, 0.08)
      var norm = Math.min(1.0, avg / peak)
      var target = norm > level ? level + (norm - level) * 0.25 : level + (norm - level) * 0.08
      beat = Math.max(beat * 0.82, Math.max(0, norm - level) * 2.2)
      level = target
    }
  }

  // ================= PHYSICAL SHAKE & BOUNCE ANIMATION =================
  SequentialAnimation {
    id: shakeAnim
    NumberAnimation { target: root; property: "shakeX"; to: -10; duration: 55; easing.type: Easing.OutSine }
    NumberAnimation { target: root; property: "shakeX"; to: 9; duration: 75; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "shakeX"; to: -7; duration: 70; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "shakeX"; to: 5; duration: 65; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "shakeX"; to: -2; duration: 60; easing.type: Easing.InOutSine }
    NumberAnimation { target: root; property: "shakeX"; to: 0; duration: 55; easing.type: Easing.OutSine }
  }

  SequentialAnimation {
    id: bounceAnim
    NumberAnimation { target: root; property: "bounceY"; to: 4; duration: 70; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "bounceY"; to: -1; duration: 90; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "bounceY"; to: 0; duration: 80; easing.type: Easing.OutQuad }
  }

  function shake() {
    shakeAnim.restart()
    bounceAnim.restart()
  }

  // ================= PEEK NOTIFICATION SYSTEM =================
  Timer {
    id: peekTimer
    interval: 2600
    onTriggered: root.isPeeking = false
  }

  function triggerPeek(icon, title, subtitle, target, durationMs) {
    if (root.isExpanded) return
    root.peekData = {
      icon: icon || "bell",
      title: title || "",
      subtitle: subtitle || "",
      target: target || "music"
    }
    root.isPeeking = true
    peekTimer.interval = durationMs || 2600
    peekTimer.restart()
    bounceAnim.restart()
  }

  // Watch for track change to trigger Peek
  onMediaTitleChanged: {
    if (mediaTitle !== "" && mediaTitle !== lastTrackSeen && isPlaying && !isExpanded) {
      lastTrackSeen = mediaTitle
      triggerPeek("music", mediaTitle, mediaArtist || playerName, "music", 2800)
    }
  }

  // Watch for battery status change to trigger Peek
  onBatteryStatusChanged: {
    if (lastBatteryStatusSeen !== "" && batteryStatus !== lastBatteryStatusSeen && !isExpanded) {
      if (batteryStatus === "Charging") {
        triggerPeek("⚡", "Charging", (batteryPct >= 0 ? batteryPct + "%" : "AC Power") + " · Power Connected", "controls", 2500)
      } else if (batteryStatus === "Discharging") {
        triggerPeek("🔋", "On Battery", (batteryPct >= 0 ? batteryPct + "%" : "Disconnected") + " · Running on battery", "controls", 2500)
      }
    }
    lastBatteryStatusSeen = batteryStatus
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
    var p = root.selectedPlayer
    if (p) root.triggerPeek("♫", p.identity || "Media Player", p.trackTitle || "Selected", "music", 2000)
  }

  function mediaAction(action, value) {
    var player = root.currentPlayer
    if (action === "volume-up" || action === "volume-down") {
      var step = action === "volume-up" ? 5 : -5
      var targetVol = Math.max(0, Math.min(100, root.systemVolume + step))
      setSystemVolume(targetVol)
      root.volumeHudLevel = targetVol
      root.showVolumeHud = true
      volumeHudTimer.restart()
      return
    }
    if (!player) return
    if (action === "play-pause" && player.canTogglePlaying) {
      player.togglePlaying()
    } else if (action === "previous" && player.canGoPrevious) {
      player.previous()
    } else if (action === "next" && player.canGoNext) {
      player.next()
    } else if (action === "seek" && player.canSeek && player.positionSupported) {
      player.position = Math.max(0, Math.min(player.length, Number(value) || 0))
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
        root.shake()
        root.triggerPeek("⏱️", timerName || "Focus Complete", "Session " + focusSessions + " finished! Great work.", "timer", 4500)
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
    triggerPeek("⏱️", timerName, root.formatTime(timerLeft) + " remaining", "timer", 2200)
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
      version: 5,
      timerTotal: timerTotal,
      timerLeft: timerLeft,
      timerDeadline: timerDeadline,
      timerRunning: timerRunning,
      timerFinished: timerFinished,
      timerName: timerName,
      timerMode: timerMode,
      focusSessions: focusSessions,
      soundEnabled: soundEnabled,
      scratchpadText: scratchpadText,
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
      scratchpadText = typeof saved.scratchpadText === "string" ? saved.scratchpadText : ""

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

  // System Controls Actions
  function setSystemVolume(pct) {
    systemVolume = pct
    systemMuted = false
    Quickshell.execDetached(["bash", scriptPath, "set-volume", String(pct)])
  }

  function toggleSystemMute() {
    systemMuted = !systemMuted
    Quickshell.execDetached(["bash", scriptPath, "toggle-mute"])
  }

  function setSystemBrightness(pct) {
    systemBrightness = pct
    Quickshell.execDetached(["bash", scriptPath, "set-brightness", String(pct)])
  }

  function toggleNightlight() {
    nightlightEnabled = !nightlightEnabled
    Quickshell.execDetached(["bash", scriptPath, "toggle-nightlight"])
    triggerPeek("🌙", "Night Light", nightlightEnabled ? "Enabled" : "Disabled", "controls", 2000)
  }

  function toggleIdle() {
    idleEnabled = !idleEnabled
    Quickshell.execDetached(["bash", scriptPath, "toggle-idle"])
    triggerPeek("☕", "Caffeine / Stay Awake", idleEnabled ? "Active" : "Standard Idle", "controls", 2000)
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
    triggerPeek("▧", "Wallpaper Changed", "Applied next Omarchy wallpaper", "controls", 2000)
  }

  function openOmarchyThemeSwitcher() {
    Quickshell.execDetached(["omarchy", "theme", "switcher"])
    root.isExpanded = false
  }

  function takeScreenshot() {
    Quickshell.execDetached(["omarchy", "screenshot"])
    root.isExpanded = false
    triggerPeek("📸", "Screenshot Taken", "Saved to Pictures/Screenshots", "shelf", 2400)
  }

  function lockSession() {
    Quickshell.execDetached(["loginctl", "lock-session"])
    root.isExpanded = false
  }

  function copyClipboardText(txt) {
    Quickshell.execDetached(["bash", scriptPath, "copy-text", txt])
    triggerPeek("📋", "Copied to Clipboard", txt.substring(0, 40) + "...", "shelf", 2000)
  }

  function clearClipboard() {
    Quickshell.execDetached(["bash", scriptPath, "clear-clipboard"])
    clipboardData = { type: "empty", text: "", image_path: "" }
    triggerPeek("📋", "Clipboard Cleared", "Buffer is now empty", "shelf", 1800)
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
    interval: 8000
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
          if (data.audio) {
            root.systemVolume = Number(data.audio.volume) || 50
            root.systemMuted = data.audio.muted === true
          }
          if (data.display) {
            root.systemBrightness = Number(data.display.brightness) || 50
          }
          if (data.system) {
            root.nightlightEnabled = data.system.nightlight === true
            root.idleEnabled = data.system.idle === true
          }
          if (data.recording) {
            root.isRecording = data.recording.active === true
          }
          if (data.agents) {
            root.agentsData = data.agents
            if (data.agents.local_models && Array.isArray(data.agents.local_models.models)) {
              root.localModelsList = data.agents.local_models.models
            }
          }
          if (data.clipboard) {
            root.clipboardData = data.clipboard
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

    // Ambient Halo Backlight (Dynamic with Cava Bass & Loudness)
    Rectangle {
      id: ambientHalo
      z: 1
      anchors.centerIn: morphCard
      width: morphCard.width + Style.space(24) + cavaVisualizer.beat * Style.space(16)
      height: morphCard.height + Style.space(24) + cavaVisualizer.beat * Style.space(16)
      radius: morphCard.radius + Style.space(12)
      color: root.isPlaying
        ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.20 + cavaVisualizer.level * 0.28)
        : "transparent"
      opacity: root.isPlaying ? Math.min(1.0, 0.35 + cavaVisualizer.level * 0.65) : 0
      visible: opacity > 0.01

      Behavior on opacity { NumberAnimation { duration: 180 } }
      Behavior on width { SpringAnimation { spring: 5.0; damping: 0.35; mass: 0.8 } }
      Behavior on height { SpringAnimation { spring: 5.0; damping: 0.35; mass: 0.8 } }
      Behavior on radius { NumberAnimation { duration: 240 } }
    }

    // THE MORPHING ISLAND CARD
    Rectangle {
      id: morphCard
      z: 2
      anchors.horizontalCenter: parent.horizontalCenter
      y: Style.space(8)

      width: root.isExpanded
        ? Style.space(480)
        : (root.isPeeking ? root.peekWidth : root.compactWidth)
      height: root.isExpanded
        ? Style.space(480)
        : (root.isPeeking ? Style.space(42) : Style.space(34))
      radius: root.isExpanded
        ? Style.space(26)
        : (root.isPeeking ? Style.space(21) : Style.space(17))

      transform: Translate {
        x: root.shakeX
        y: root.bounceY
      }

      gradient: Gradient {
        GradientStop { position: 0.0; color: "#1c1c20" }
        GradientStop { position: 0.28; color: "#09090c" }
        GradientStop { position: 1.0; color: "#030305" }
      }

      border.color: root.isExpanded
        ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.55)
        : (root.isPeeking
          ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
          : (root.capsuleHovered ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.12)))
      border.width: 1
      clip: true

      Behavior on width { SpringAnimation { spring: 5.0; damping: 0.35; mass: 0.8 } }
      Behavior on height { SpringAnimation { spring: 5.0; damping: 0.35; mass: 0.8 } }
      Behavior on radius { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
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
        opacity: root.isExpanded ? 0.35 : (root.capsuleHovered || root.isPeeking ? 0.28 : 0.16)
        Behavior on opacity { NumberAnimation { duration: 180 } }
      }

      // Compact & Peek Click & Hover Handler
      MouseArea {
        id: compactMouse
        anchors.fill: parent
        enabled: !root.isExpanded
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (root.isPeeking) {
            root.activeTab = root.peekData.target || "music"
            root.isPeeking = false
            root.isExpanded = true
            return
          }
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
      // 1. PEEK BANNER VIEW (Visible during Notification Peek)
      // -------------------------------------------------------------
      Item {
        anchors.fill: parent
        visible: !root.isExpanded && root.isPeeking
        opacity: !root.isExpanded && root.isPeeking ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(10)

          // Leading Badge
          Rectangle {
            Layout.preferredWidth: Style.space(26)
            Layout.preferredHeight: Style.space(26)
            radius: Style.space(8)
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
            clip: true

            Image {
              anchors.fill: parent
              visible: root.peekData.icon === "music" && root.artUrl !== "" && status !== Image.Error
              source: visible ? root.artUrl : ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }

            Text {
              anchors.centerIn: parent
              visible: !(root.peekData.icon === "music" && root.artUrl !== "")
              text: root.peekData.icon === "music" ? "♫" : (root.peekData.icon || "🔔")
              font.pixelSize: Style.font.caption
              color: root.accent
            }
          }

          // Center: Title & Subtitle
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              text: root.peekData.title
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
              color: root.capsuleInk
            }
            Text {
              Layout.fillWidth: true
              text: root.peekData.subtitle
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.space(10)
              color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.65)
            }
          }

          // Trailing Indicator / Action
          Text {
            text: "↗"
            font.pixelSize: Style.font.body
            color: root.accent
          }
        }
      }

      // -------------------------------------------------------------
      // 2. COMPACT VIEW CONTENT (Visible when resting & not peeking)
      // -------------------------------------------------------------
      Item {
        anchors.fill: parent
        visible: !root.isExpanded && !root.isPeeking
        opacity: !root.isExpanded && !root.isPeeking ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        // Volume HUD on Scroll
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
            Layout.preferredWidth: Style.space(80)
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

        // Music Mode
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

          // Trailing: 4-Bar Cava Equalizer
          Row {
            spacing: Style.space(2.4)
            visible: root.isPlaying
            Layout.alignment: Qt.AlignVCenter
            Repeater {
              model: 4
              Rectangle {
                required property int index
                width: Style.space(2.4)
                height: root.isPlaying
                  ? Math.max(Style.space(3), Math.min(Style.space(16), (cavaVisualizer.bars[index] || 0.2) * Style.space(16)))
                  : Style.space(3)
                radius: Style.space(1.2)
                color: root.accent

                Behavior on height { NumberAnimation { duration: 65 } }
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

        // Timer Only Mode
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

        // Resting Idle Mode (Clock & Battery)
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
              text: root.batteryStatus === "Charging" ? "⚡" : root.batteryPct <= 20 ? "🪫" : "🔋"
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
      // 3. EXPANDED VIEW CONTENT (Full Rich Card)
      // -------------------------------------------------------------
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(10)
        visible: root.isExpanded
        opacity: root.isExpanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // Top Navigation Header (Capsule handle + 5 Tabs)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          // Capsule Morph Handle (Click to Collapse)
          Rectangle {
            Layout.preferredWidth: Style.space(34)
            Layout.preferredHeight: Style.space(28)
            radius: Style.space(8)
            color: Qt.rgba(1, 1, 1, 0.08)
            Text {
              anchors.centerIn: parent
              text: "✕"
              font.pixelSize: Style.space(12)
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
                { key: "shelf", label: "Shelf", icon: "📋" },
                { key: "controls", label: "Controls", icon: "🎛️" }
              ]
              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                height: Style.space(28)
                radius: Style.space(7)
                color: root.activeTab === modelData.key ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : root.glass
                border.color: root.activeTab === modelData.key ? root.accent : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Row {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    text: modelData.icon
                    font.pixelSize: Style.space(11)
                  }
                  Text {
                    text: modelData.label
                    color: root.activeTab === parent.parent.modelData.key ? root.capsuleInk : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6)
                    font.family: Style.font.family
                    font.pixelSize: Style.space(11)
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

        // ================= TAB 1: MUSIC =================
        ColumnLayout {
          visible: root.activeTab === "music"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(12)

          // Album Artwork & Track Info
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(14)

            Rectangle {
              Layout.preferredWidth: Style.space(95)
              Layout.preferredHeight: Style.space(95)
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
              spacing: Style.space(3)
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

        // ================= TAB 2: FOCUS STUDIO =================
        ColumnLayout {
          visible: root.activeTab === "timer"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

          // Big Timer Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(90)
            radius: Style.space(16)
            color: root.glass
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
            border.width: 1

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 1
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
                font.pixelSize: Style.space(36)
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
              Layout.preferredWidth: Style.space(34)
              Layout.preferredHeight: Style.space(34)
              radius: Style.space(8)
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

        // ================= TAB 3: AI STUDIO =================
        ColumnLayout {
          visible: root.activeTab === "agents"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(8)

          // Quick Prompt Bar
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Controls.TextField {
              id: agentPromptField
              Layout.fillWidth: true
              placeholderText: "Quick prompt: e.g. fix swap or run unit tests..."
              color: root.capsuleInk
              placeholderTextColor: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.4)
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              selectByMouse: true
              background: Rectangle { radius: Style.space(8); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              onAccepted: {
                if (text.trim() !== "") {
                  root.launchTerminal("agy \"" + text.trim().replace(/"/g, "\\\"") + "\"")
                  text = ""
                }
              }
            }
            Rectangle {
              Layout.preferredWidth: Style.space(64)
              Layout.preferredHeight: Style.space(32)
              radius: Style.space(8)
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
              border.color: root.accent
              Text { anchors.centerIn: parent; text: "Run"; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (agentPromptField.text.trim() !== "") {
                    root.launchTerminal("agy \"" + agentPromptField.text.trim().replace(/"/g, "\\\"") + "\"")
                    agentPromptField.text = ""
                  }
                }
              }
            }
          }

          // Agents List
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            // Google Antigravity
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(48)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(8)
                Rectangle { width: Style.space(30); height: Style.space(30); radius: Style.space(7); color: Qt.rgba(0.2, 0.6, 1, 0.18)
                  Text { anchors.centerIn: parent; text: "🤖"; font.pixelSize: Style.font.caption } }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                  Text { text: "Google Antigravity"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { text: root.agentsData.antigravity && root.agentsData.antigravity.active ? "● Active Session" : "Installed & Ready"; font.pixelSize: Style.space(9); color: root.agentsData.antigravity && root.agentsData.antigravity.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
                Rectangle { width: Style.space(60); height: Style.space(24); radius: Style.space(6); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                  Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.space(11); color: root.capsuleInk; font.weight: Font.DemiBold }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("agy") } }
              }
            }

            // Claude Code
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(48)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(8)
                Rectangle { width: Style.space(30); height: Style.space(30); radius: Style.space(7); color: Qt.rgba(0.9, 0.4, 0.2, 0.18)
                  Text { anchors.centerIn: parent; text: "⚡"; font.pixelSize: Style.font.caption } }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                  Text { text: "Claude Code"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { text: root.agentsData.claude_code && root.agentsData.claude_code.active ? "● Active Session" : "Installed & Ready"; font.pixelSize: Style.space(9); color: root.agentsData.claude_code && root.agentsData.claude_code.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
                Rectangle { width: Style.space(60); height: Style.space(24); radius: Style.space(6); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                  Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.space(11); color: root.capsuleInk; font.weight: Font.DemiBold }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("claude") } }
              }
            }

            // Codex CLI
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(48)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(8)
                Rectangle { width: Style.space(30); height: Style.space(30); radius: Style.space(7); color: Qt.rgba(0.1, 0.8, 0.5, 0.18)
                  Text { anchors.centerIn: parent; text: "💻"; font.pixelSize: Style.font.caption } }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                  Text { text: "Codex CLI"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { text: root.agentsData.codex && root.agentsData.codex.active ? "● Active Session" : "Installed & Ready"; font.pixelSize: Style.space(9); color: root.agentsData.codex && root.agentsData.codex.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
                Rectangle { width: Style.space(60); height: Style.space(24); radius: Style.space(6); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                  Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.space(11); color: root.capsuleInk; font.weight: Font.DemiBold }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("codex") } }
              }
            }
          }

          // Local Models (llama-swap / llama.cpp)
          Text {
            text: "Local Models (llama-swap :18080 · " + root.localModelsList.length + " available)"
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }

          ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Style.space(4)
            model: root.localModelsList
            delegate: Rectangle {
              required property var modelData
              width: parent ? parent.width : 0
              height: Style.space(34)
              radius: Style.space(7)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.08)
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                Rectangle {
                  width: Style.space(8); height: Style.space(8); radius: width / 2
                  color: parent.parent.modelData.status === "loaded" ? "#34d399" : Qt.rgba(1, 1, 1, 0.3)
                }
                Text {
                  Layout.fillWidth: true
                  text: parent.parent.modelData.id || "Model"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  color: root.capsuleInk
                }
                Rectangle {
                  width: Style.space(48); height: Style.space(20); radius: Style.space(5)
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                  Text { anchors.centerIn: parent; text: "Select"; font.pixelSize: Style.space(10); color: root.capsuleInk }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.launchTerminal("curl -s -N http://127.0.0.1:18080/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"" + parent.parent.parent.modelData.id + "\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello! Tell me about yourself.\"}],\"stream\":true}'")
                    }
                  }
                }
              }
            }
          }
        }

        // ================= TAB 4: SHELF & CLIPBOARD =================
        ColumnLayout {
          visible: root.activeTab === "shelf"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

          // Live Clipboard Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(110)
            radius: Style.space(12)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)
            clip: true

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(6)

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "Clipboard (" + (root.clipboardData.type || "empty") + ")"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.weight: Font.DemiBold
                  color: root.accent
                }
                Item { Layout.fillWidth: true }
                Controls.Button {
                  text: "Clear"
                  onClicked: root.clearClipboard()
                  background: Rectangle { radius: Style.space(6); color: Qt.rgba(1, 1, 1, 0.08) }
                  contentItem: Text { text: "Clear"; font.pixelSize: Style.space(10); color: root.capsuleInk }
                }
              }

              // Image Clip Preview
              Image {
                visible: root.clipboardData.type === "image" && root.clipboardData.image_path !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: visible ? "file://" + root.clipboardData.image_path : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

              // Text Clip Preview
              Text {
                visible: root.clipboardData.type === "text"
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.clipboardData.text || "Empty"
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                color: root.capsuleInk
                elide: Text.ElideRight
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
              }

              // Empty Clip Placeholder
              Text {
                visible: root.clipboardData.type === "empty"
                Layout.alignment: Qt.AlignCenter
                text: "Clipboard buffer is empty"
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.4)
              }
            }
          }

          // Scratchpad Note
          Text {
            text: "Island Scratchpad (Auto-saved)"
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Style.space(12)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)

            Controls.ScrollView {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              clip: true

              Controls.TextArea {
                id: scratchpadField
                text: root.scratchpadText
                placeholderText: "Quick notes, links, or draft prompts..."
                color: root.capsuleInk
                placeholderTextColor: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.4)
                font.family: Style.font.family
                font.pixelSize: Style.space(12)
                wrapMode: Text.Wrap
                selectByMouse: true
                background: null
                onTextChanged: {
                  root.scratchpadText = text
                  root.persistState()
                }
              }
            }
          }
        }

        // ================= TAB 5: CONTROLS & DESK =================
        ColumnLayout {
          visible: root.activeTab === "controls"
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

          // 1. Audio Volume Slider Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(48)
            radius: Style.space(10)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(28); height: Style.space(28); radius: Style.space(7)
                color: root.systemMuted ? "#ef4444" : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                Text {
                  anchors.centerIn: parent
                  text: root.systemMuted ? "🔇" : root.systemVolume < 50 ? "🔉" : "🔊"
                  font.pixelSize: Style.space(12)
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleSystemMute()
                }
              }

              // Custom Draggable Volume Slider
              Rectangle {
                id: volTrack
                Layout.fillWidth: true
                height: Style.space(8)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.14)

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1, root.systemVolume / 100))
                  height: parent.height
                  radius: height / 2
                  color: root.systemMuted ? "#9ca3af" : root.accent
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: function(mouse) {
                    if (pressed && width > 0) {
                      var pct = Math.round(Math.max(0, Math.min(100, (mouse.x / width) * 100)))
                      root.setSystemVolume(pct)
                    }
                  }
                  onClicked: function(mouse) {
                    if (width > 0) {
                      var pct = Math.round(Math.max(0, Math.min(100, (mouse.x / width) * 100)))
                      root.setSystemVolume(pct)
                    }
                  }
                }
              }

              Text {
                text: root.systemVolume + "%"
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                font.weight: Font.DemiBold
                color: root.capsuleInk
              }
            }
          }

          // 2. Display Brightness Slider Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(48)
            radius: Style.space(10)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(28); height: Style.space(28); radius: Style.space(7)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                Text {
                  anchors.centerIn: parent
                  text: "☀️"
                  font.pixelSize: Style.space(12)
                }
              }

              // Custom Draggable Brightness Slider
              Rectangle {
                id: brightTrack
                Layout.fillWidth: true
                height: Style.space(8)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.14)

                Rectangle {
                  width: parent.width * Math.max(0, Math.min(1, root.systemBrightness / 100))
                  height: parent.height
                  radius: height / 2
                  color: "#f59e0b"
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: function(mouse) {
                    if (pressed && width > 0) {
                      var pct = Math.round(Math.max(0, Math.min(100, (mouse.x / width) * 100)))
                      root.setSystemBrightness(pct)
                    }
                  }
                  onClicked: function(mouse) {
                    if (width > 0) {
                      var pct = Math.round(Math.max(0, Math.min(100, (mouse.x / width) * 100)))
                      root.setSystemBrightness(pct)
                    }
                  }
                }
              }

              Text {
                text: root.systemBrightness + "%"
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                font.weight: Font.DemiBold
                color: root.capsuleInk
              }
            }
          }

          // 3. Workspaces Row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Repeater {
              model: Hyprland.workspaces.values
              Rectangle {
                required property var modelData
                Layout.fillWidth: true
                height: Style.space(34)
                radius: Style.space(8)
                color: modelData.focused ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass
                border.color: modelData.focused ? root.accent : Qt.rgba(1, 1, 1, 0.1)
                Column {
                  anchors.centerIn: parent; spacing: 1
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.name || String(parent.parent.modelData.id); font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: (parent.parent.modelData.toplevels ? parent.parent.modelData.toplevels.values.length : 0) + " win"; font.pixelSize: Style.space(8); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { parent.modelData.activate(); root.isExpanded = false } }
              }
            }
          }

          // 4. Quick System Action Buttons
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Controls.Button {
              Layout.fillWidth: true
              text: "▧ Wallpaper"
              onClicked: root.nextOmarchyBackground()
              background: Rectangle { radius: Style.space(8); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(11); color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "◐ Theme"
              onClicked: root.openOmarchyThemeSwitcher()
              background: Rectangle { radius: Style.space(8); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(11); color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "📸 Shot"
              onClicked: root.takeScreenshot()
              background: Rectangle { radius: Style.space(8); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(11); color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: root.nightlightEnabled ? "🌙 Night On" : "🌙 Night"
              onClicked: root.toggleNightlight()
              background: Rectangle { radius: Style.space(8); color: root.nightlightEnabled ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass; border.color: root.nightlightEnabled ? root.accent : Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(11); color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: root.idleEnabled ? "☕ Awake" : "☕ Sleep"
              onClicked: root.toggleIdle()
              background: Rectangle { radius: Style.space(8); color: root.idleEnabled ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass; border.color: root.idleEnabled ? root.accent : Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(11); color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "🔒 Lock"
              onClicked: root.lockSession()
              background: Rectangle { radius: Style.space(8); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(11); color: root.capsuleInk }
            }
          }
        }
      }
    }

    // SPLIT SATELLITE BUBBLE (Timer / Stopwatch active while music plays)
    Rectangle {
      id: timerSatellite
      z: 2
      visible: !root.isExpanded && !root.isPeeking && root.hasTrack && (root.timerActive || root.stopwatchVisible)
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
