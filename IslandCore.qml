import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "components" as IslandComponents
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  // Master Expansion & Peek States
  property bool isExpanded: false
  property bool isPeeking: false
  property string activeTab: "home"
  readonly property var tabOrder: ["home", "music", "timer", "agents", "stats", "shelf", "system"]
  readonly property string activeSectionTitle: {
    if (activeTab === "home") return "Your island"
    if (activeTab === "music") return hasTrack ? "Now playing" : "Music"
    if (activeTab === "timer") return "Focus studio"
    if (activeTab === "agents") return "Agent activity"
    if (activeTab === "stats") return "System health"
    if (activeTab === "shelf") return "Your shelf"
    return "Quick controls"
  }
  readonly property string activeSectionSubtitle: {
    if (activeTab === "home") return "A quick look at what matters right now"
    if (activeTab === "music") return hasTrack ? mediaTitle : "Your music, in one place"
    if (activeTab === "timer") return timerActive ? (timerName || "Focus session") : "Timers and deep work"
    if (activeTab === "agents") return "Local tools and live sessions"
    if (activeTab === "stats") return "Hardware and network at a glance"
    if (activeTab === "shelf") return "Clipboard, screenshots and notes"
    return "Sound, display and connectivity"
  }
  readonly property string activeSectionIcon: {
    if (activeTab === "home") return "⌂"
    if (activeTab === "music") return "♫"
    if (activeTab === "timer") return "◷"
    if (activeTab === "agents") return "⌘"
    if (activeTab === "stats") return "◫"
    if (activeTab === "shelf") return "▤"
    return "☼"
  }
  property int previousTabIndex: 0
  property real tabContentX: 0
  property real tabContentOpacity: 1
  property string positionMode: "auto" // "auto", "flush", "snug", "floating"
  property int topOffset: 0
  property int detectedTopBarHeight: 0

  readonly property int effectiveTopOffset: {
    if (positionMode === "flush") return 0
    if (positionMode === "snug") return Style.space(2)
    if (positionMode === "floating") return Style.space(6)
    // "auto" mode:
    // If top bar is detected (> 0), sit smoothly below it with an aesthetic 3px gap
    // If no top bar exists (y=0, h=0), stay flush with top bezel (0px)
    return detectedTopBarHeight > 0 ? (detectedTopBarHeight + Style.space(3)) : 0
  }

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

  // Telemetry & Hardware
  property int batteryPct: -1
  property string batteryStatus: "Unavailable"
  property bool batteryAvailable: false
  property string lastBatteryStatusSeen: ""
  property bool isRecording: false
  property var agentsData: ({})
  property var localModelsList: []
  property var clipboardData: ({ type: "empty", text: "", image_path: "" })
  property var hardwareData: ({
    cpu: { pct: 0 },
    ram: { used_mb: 0, total_mb: 0, pct: 0 },
    swap: { used_mb: 0, total_mb: 0, pct: 0 },
    gpu: { name: "None", used_mb: 0, total_mb: 0, temp_c: 0 }
  })
  property var recentScreenshots: []
  property string clockLabel: Qt.formatTime(new Date(), "h:mm AP")

  // Connectivity, Updates & Disk Telemetry
  property var connectivityData: ({ wifi: true, bluetooth: false })
  property int systemUpdatesCount: 0
  property int trashItemsCount: 0
  readonly property int netDownKb: hardwareData && hardwareData.net ? (Number(hardwareData.net.down_kb) || 0) : 0
  readonly property int netUpKb: hardwareData && hardwareData.net ? (Number(hardwareData.net.up_kb) || 0) : 0
  readonly property var diskData: hardwareData && hardwareData.disk ? hardwareData.disk : ({ used_mb: 0, total_mb: 0, pct: "0%" })

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

  // Peek Banners & Interactive Permission Interceptor
  property var peekData: ({ icon: "music", title: "", subtitle: "", target: "music" })
  property var agentPendingRequest: null

  // State persistence
  property bool stateReady: false
  property bool stateTouched: false

  onActiveTabChanged: {
    var nextIndex = root.tabOrder.indexOf(root.activeTab)
    if (nextIndex < 0 || !root.stateReady) {
      root.previousTabIndex = nextIndex
      root.tabContentX = 0
      root.tabContentOpacity = 1
      return
    }
    if (nextIndex === root.previousTabIndex) return

    var direction = nextIndex > root.previousTabIndex ? 1 : -1
    root.previousTabIndex = nextIndex
    if (Style.reduceMotion) {
      root.tabContentX = 0
      root.tabContentOpacity = 1
      return
    }

    root.tabContentX = direction * Style.space(18)
    root.tabContentOpacity = 0
    tabContentEntrance.restart()
  }

  ParallelAnimation {
    id: tabContentEntrance
    NumberAnimation {
      target: root
      property: "tabContentX"
      to: 0
      duration: Style.duration(180)
      easing.type: Easing.Bezier
      easing.bezierCurve: Style.easeOut
    }
    NumberAnimation {
      target: root
      property: "tabContentOpacity"
      to: 1
      duration: Style.duration(140)
      easing.type: Easing.OutCubic
    }
  }

  // Bounding rect for input masking in Service.qml
  readonly property var maskItem: morphCard
  readonly property var satelliteItem: timerSatellite

  // Peek Width calculation
  readonly property real peekWidth: {
    if (root.agentPendingRequest !== null) return Style.space(450)
    var titleLen = (root.peekData.title || "").length
    var subLen = (root.peekData.subtitle || "").length
    var maxLen = Math.max(titleLen, subLen)
    return Math.min(Style.space(430), Math.max(Style.space(270), Style.space(90) + maxLen * Style.space(7.2)))
  }

  // Compact width calculation
  readonly property real compactWidth: {
    if (showVolumeHud) return Style.space(170)
    if (isRecording) return Style.space(170)
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

  // ================= AGENT BRIDGE & PERMISSION INTERCEPTOR =================
  readonly property string agentSocketDir:
    (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dynamic-island"
  readonly property string agentSocketPath: agentSocketDir + "/agents.sock"

  Process {
    id: prepSocket
    running: true
    command: ["sh", "-c", "mkdir -p \"$1\" && chmod 700 \"$1\" && rm -f \"$2\"", "sh", root.agentSocketDir, root.agentSocketPath]
    onExited: agentSocketServer.active = true
  }

  SocketServer {
    id: agentSocketServer
    active: false
    path: root.agentSocketPath

    handler: Socket {
      id: incomingAgentSocket
      property string activeReqId: ""

      parser: SplitParser {
        onRead: function(line) {
          root.handleAgentLine(line, incomingAgentSocket)
        }
      }
      onConnectedChanged: {
        if (!connected && activeReqId !== "") {
          if (root.agentPendingRequest && root.agentPendingRequest.id === activeReqId) {
            root.agentPendingRequest = null
          }
        }
      }
    }
  }

  function handleAgentLine(line, sock) {
    if (!line) return
    try {
      var msg = JSON.parse(line)
      if (msg.cmd === "toggle" || msg.event === "toggle") {
        root.isExpanded = !root.isExpanded
      } else if (msg.cmd === "expand" || msg.event === "expand") {
        if (msg.tab) root.activeTab = msg.tab
        root.isExpanded = true
      } else if (msg.cmd === "collapse" || msg.event === "collapse") {
        root.isExpanded = false
      } else if (msg.cmd === "peek" || msg.event === "peek") {
        root.triggerPeek(msg.icon || "✨", msg.title || "Dynamic Island Pro", msg.subtitle || "", msg.target || "music", msg.duration || 2500)
      } else if (msg.event === "PermissionRequest") {
        var reqId = msg.request || ("req-" + Date.now())
        sock.activeReqId = reqId
        root.agentPendingRequest = {
          id: reqId,
          agent: msg.agent || "Agent",
          tool: msg.tool || "Command",
          title: msg.title || msg.tool || "Permission Request",
          detail: msg.detail || msg.command || "",
          socket: sock
        }
        root.shake()
        root.triggerPeek("🤖", (msg.agent || "Agent") + ": " + (msg.title || msg.tool), "Permission required · Click to answer", "agents", 8000)
      } else if (msg.event === "PreToolUse") {
        root.triggerPeek("🤖", (msg.agent || "Agent") + " running " + (msg.tool || "tool"), msg.title || "", "agents", 2200)
      } else if (msg.event === "done" || msg.event === "SessionFinished") {
        root.triggerPeek("✓", (msg.agent || "Agent") + " finished", msg.project || "Turn complete", "agents", 2500)
      }
    } catch (e) {}
  }

  function resolveAgentPermission(behavior) {
    if (root.agentPendingRequest && root.agentPendingRequest.socket) {
      try {
        root.agentPendingRequest.socket.write(JSON.stringify({ behavior: behavior }) + "\n")
      } catch (e) {}
    }
    var wasAgent = root.agentPendingRequest ? root.agentPendingRequest.agent : "Agent"
    root.agentPendingRequest = null
    root.triggerPeek(behavior === "allow" ? "✓" : "✕",
      behavior === "allow" ? "Permission Allowed" : "Permission Denied",
      wasAgent + " continuing", "agents", 1800)
  }

  // ================= REDUCED, COORDINATED ALERT MOTION =================
  SequentialAnimation {
    id: shakeAnim
    running: false
    NumberAnimation { target: root; property: "shakeX"; to: -3; duration: Style.duration(55); easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "shakeX"; to: 2; duration: Style.duration(70); easing.type: Easing.OutCubic }
    NumberAnimation { target: root; property: "shakeX"; to: 0; duration: Style.duration(75); easing.type: Easing.OutCubic }
  }

  function shake() {
    if (Style.reduceMotion) {
      root.shakeX = 0
      return
    }
    shakeAnim.restart()
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
        triggerPeek("⚡", "Charging", (batteryPct >= 0 ? batteryPct + "%" : "AC Power") + " · Power Connected", "system", 2500)
      } else if (batteryStatus === "Discharging") {
        triggerPeek("🔋", "On Battery", (batteryPct >= 0 ? batteryPct + "%" : "Disconnected") + " · Running on battery", "system", 2500)
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
  function availableAgentCount() {
    var agents = root.agentsData || ({})
    var keys = ["codex", "claude_code", "antigravity", "local_models"]
    var count = 0
    for (var i = 0; i < keys.length; i++) {
      if (agents[keys[i]] && agents[keys[i]].available === true) count++
    }
    return count
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
      version: 7,
      positionMode: positionMode,
      topOffset: topOffset,
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
      if (typeof saved.positionMode === "string") {
        positionMode = saved.positionMode
      } else if (typeof saved.topOffset === "number") {
        if (saved.topOffset === 0) positionMode = "flush"
        else if (saved.topOffset === 2) positionMode = "snug"
        else if (saved.topOffset === 6) positionMode = "floating"
      }
      if (typeof saved.topOffset === "number") topOffset = saved.topOffset
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
    triggerPeek("🌙", "Night Light", nightlightEnabled ? "Enabled" : "Disabled", "system", 2000)
  }

  function toggleIdle() {
    idleEnabled = !idleEnabled
    Quickshell.execDetached(["bash", scriptPath, "toggle-idle"])
    triggerPeek("☕", "Caffeine / Stay Awake", idleEnabled ? "Active" : "Standard Idle", "system", 2000)
  }

  function optimizeMemory() {
    Quickshell.execDetached(["bash", scriptPath, "optimize-memory"])
    triggerPeek("⚡", "Memory Optimized", "Caches cleared & pages synced", "stats", 2200)
    refreshTelemetry()
  }

  function stopRecording() {
    Quickshell.execDetached(["bash", scriptPath, "stop-recording"])
    isRecording = false
    triggerPeek("🔴", "Recording Stopped", "Capture saved", "shelf", 2000)
  }

  function toggleWifi() {
    Quickshell.execDetached(["bash", scriptPath, "toggle-wifi"])
    connectivityData.wifi = !connectivityData.wifi
    triggerPeek(connectivityData.wifi ? "📶" : "🚫", connectivityData.wifi ? "WiFi Enabled" : "WiFi Disabled", "", "system", 1800)
    refreshTelemetry()
  }

  function toggleBluetooth() {
    Quickshell.execDetached(["bash", scriptPath, "toggle-bluetooth"])
    connectivityData.bluetooth = !connectivityData.bluetooth
    triggerPeek(connectivityData.bluetooth ? "ᛒ" : "🚫", connectivityData.bluetooth ? "Bluetooth On" : "Bluetooth Off", "", "system", 1800)
    refreshTelemetry()
  }

  function emptyTrash() {
    Quickshell.execDetached(["bash", scriptPath, "empty-trash"])
    trashItemsCount = 0
    triggerPeek("🗑️", "Trash Cleaned", "Temporary items permanently deleted", "shelf", 2000)
    refreshTelemetry()
  }

  function checkUpdates() {
    Quickshell.execDetached(["bash", scriptPath, "check-updates"])
    triggerPeek("📦", "Checking Updates", "Refreshing package repositories...", "system", 1800)
    refreshTelemetry()
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
    triggerPeek("▧", "Wallpaper Changed", "Applied next Omarchy wallpaper", "system", 2000)
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

  function openFile(filePath) {
    Quickshell.execDetached(["xdg-open", filePath])
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
    interval: 6000
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
          if (typeof data.top_bar_height === "number") {
            root.detectedTopBarHeight = data.top_bar_height
          }
          if (data.system) {
            root.nightlightEnabled = data.system.nightlight === true
            root.idleEnabled = data.system.idle === true
            if (data.system.connectivity) {
              root.connectivityData = data.system.connectivity
            }
            if (typeof data.system.updates === "number") {
              root.systemUpdatesCount = data.system.updates
            }
            if (typeof data.system.trash === "number") {
              root.trashItemsCount = data.system.trash
            }
          }
          if (data.recording) {
            root.isRecording = data.recording.active === true
          }
          if (data.hardware) {
            root.hardwareData = data.hardware
          }
          if (data.screenshots) {
            root.recentScreenshots = data.screenshots
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
      width: morphCard.width + Style.space(26)
      height: morphCard.height + Style.space(26)
      radius: morphCard.radius + Style.space(12)
      color: root.isPlaying
        ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.20 + cavaVisualizer.level * 0.30)
        : "transparent"
      opacity: root.isPlaying ? Math.min(1.0, 0.35 + cavaVisualizer.level * 0.65) : 0
      visible: opacity > 0.01

      Behavior on opacity { NumberAnimation { duration: Style.duration(100); easing.type: Easing.OutCubic } }
      Behavior on width {
        NumberAnimation {
          duration: Style.duration(root.isExpanded ? 240 : 160)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }
      Behavior on height {
        NumberAnimation {
          duration: Style.duration(root.isExpanded ? 240 : 160)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }
      Behavior on radius { NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
    }

    // THE MORPHING ISLAND CARD (Physical Liquid Glass Pill)
    Rectangle {
      id: morphCard
      z: 2
      anchors.horizontalCenter: parent.horizontalCenter
      y: root.effectiveTopOffset
      Behavior on y {
        NumberAnimation {
          duration: Style.duration(root.isExpanded ? 240 : 160)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }

      width: root.isExpanded
        ? Style.space(520)
        : (root.isPeeking ? root.peekWidth : root.compactWidth)
      height: root.isExpanded
        ? Style.space(520)
        : (root.isPeeking ? Style.space(42) : Style.space(34))
      radius: root.isExpanded
        ? Style.space(26)
        : (root.isPeeking ? Style.space(21) : Style.space(17))

      // Physical spring scale response on click and hover
      scale: compactMouse.pressed ? 0.97 : (root.capsuleHovered ? 1.01 : 1.0)
      transformOrigin: Item.Top
      Behavior on scale {
        NumberAnimation {
          duration: Style.duration(compactMouse.pressed ? 80 : 120)
          easing.type: Easing.OutCubic
        }
      }

      transform: Translate {
        x: root.shakeX
      }

      color: "#08090d"

      border.color: root.isExpanded
        ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.55)
        : (root.agentPendingRequest !== null
          ? "#f59e0b"
          : (root.isPeeking
            ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.45)
            : (root.capsuleHovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12))))
      border.width: root.isExpanded ? 1.5 : 1
      clip: true

      Rectangle {
        z: 0
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: root.isExpanded ? Style.space(150) : parent.height
        radius: parent.radius
        gradient: Gradient {
          GradientStop { position: 0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.isExpanded ? 0.18 : 0.05) }
          GradientStop { position: 0.62; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.025) }
          GradientStop { position: 1; color: "transparent" }
        }
      }

      Behavior on width {
        NumberAnimation {
          duration: Style.duration(root.isExpanded ? 240 : 160)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }
      Behavior on height {
        NumberAnimation {
          duration: Style.duration(root.isExpanded ? 240 : 160)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }
      Behavior on radius { NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
      Behavior on border.color { ColorAnimation { duration: Style.duration(160); easing.type: Easing.InOutQuad } }

      // Physical Specular Curved Glass Edge
      Rectangle {
        anchors.top: parent.top
        anchors.topMargin: root.effectiveTopOffset === 0 ? 0 : 1.2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - Style.space(28))
        height: 1.2
        radius: 0.6
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.45) }
          GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: root.isExpanded ? 0.4 : (root.capsuleHovered || root.isPeeking ? 0.35 : 0.22)
        Behavior on opacity { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
      }

      // Compact & Peek Click & Hover Handler
      MouseArea {
        id: compactMouse
        anchors.fill: parent
        scale: 1 / morphCard.scale
        transformOrigin: Item.Top
        enabled: !root.isExpanded
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (root.agentPendingRequest !== null) {
            root.activeTab = "agents"
            root.isExpanded = true
            return
          }
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
        id: peekView
        anchors.fill: parent
        readonly property bool shown: !root.isExpanded && (root.isPeeking || root.agentPendingRequest !== null)
        visible: shown || opacity > 0.01
        enabled: shown
        opacity: shown ? 1 : 0
        Behavior on opacity {
          NumberAnimation {
            duration: Style.duration(peekView.shown ? 140 : 90)
            easing.type: Easing.OutCubic
          }
        }

        // Agent Permission Request Peek Banner
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)
          visible: root.agentPendingRequest !== null

          Rectangle {
            Layout.preferredWidth: Style.space(26)
            Layout.preferredHeight: Style.space(26)
            radius: Style.space(7)
            color: Qt.rgba(0.96, 0.62, 0.04, 0.2)
            Text { anchors.centerIn: parent; text: "🤖"; font.pixelSize: Style.font.caption }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
              Layout.fillWidth: true
              text: root.agentPendingRequest ? (root.agentPendingRequest.agent + " · " + root.agentPendingRequest.tool) : "Permission Request"
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
              color: root.capsuleInk
            }
            Text {
              Layout.fillWidth: true
              text: root.agentPendingRequest ? root.agentPendingRequest.detail : ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.space(10)
              color: "#f59e0b"
            }
          }

          Row {
            spacing: Style.space(4)
            Rectangle {
              width: Style.space(48); height: Style.space(24); radius: Style.space(6)
              color: "#10b981"
              Text { anchors.centerIn: parent; text: "Allow"; font.pixelSize: Style.space(10); font.weight: Font.Bold; color: "#064e3b" }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.resolveAgentPermission("allow") }
            }
            Rectangle {
              width: Style.space(44); height: Style.space(24); radius: Style.space(6)
              color: Qt.rgba(1, 1, 1, 0.1)
              Text { anchors.centerIn: parent; text: "Deny"; font.pixelSize: Style.space(10); font.weight: Font.DemiBold; color: root.capsuleInk }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.resolveAgentPermission("deny") }
            }
          }
        }

        // Standard Event Peek Banner
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(10)
          visible: root.agentPendingRequest === null

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
        id: compactView
        anchors.fill: parent
        readonly property bool shown: !root.isExpanded && !root.isPeeking && root.agentPendingRequest === null
        visible: shown || opacity > 0.01
        enabled: shown
        opacity: shown ? 1 : 0
        Behavior on opacity {
          NumberAnimation {
            duration: Style.duration(compactView.shown ? 140 : 90)
            easing.type: Easing.OutCubic
          }
        }

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

        // Screen Recording Mode
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(8)
          visible: !root.showVolumeHud && root.isRecording

          Rectangle {
            width: Style.space(8); height: Style.space(8); radius: width / 2
            color: "#ef4444"
          }
          Text {
            Layout.fillWidth: true
            text: "Recording Active"
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }
          Rectangle {
            width: Style.space(38); height: Style.space(20); radius: Style.space(5)
            color: Qt.rgba(0.9, 0.2, 0.2, 0.25)
            Text { anchors.centerIn: parent; text: "Stop"; font.pixelSize: Style.space(9); font.weight: Font.Bold; color: "#f87171" }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.stopRecording() }
          }
        }

        // Music Mode
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(6)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)
          visible: !root.showVolumeHud && !root.isRecording && root.hasTrack

          // Album Art / Vinyl
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
                  && !Style.reduceMotion
                loops: Animation.Infinite
                from: 0; to: 360; duration: Style.duration(4000)
              }
              Rectangle {
                anchors.centerIn: parent
                width: Style.space(6); height: Style.space(6); radius: width / 2
                color: root.accent
              }
            }
          }

          // Track Title & Artist
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

          // 4-Bar Cava Equalizer
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
                Behavior on height { NumberAnimation { duration: Style.duration(65); easing.type: Easing.OutCubic } }
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
          visible: !root.showVolumeHud && !root.isRecording && !root.hasTrack && root.timerActive

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
          visible: !root.showVolumeHud && !root.isRecording && !root.hasTrack && !root.timerActive

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
              text: root.batteryAvailable
                ? (root.batteryStatus === "Charging" ? "⚡" : root.batteryPct <= 20 ? "🪫" : "🔋")
                : (root.netDownKb > 50 ? "⚡" : "🌐")
              font.pixelSize: Style.font.caption
            }
            Text {
              text: root.batteryAvailable
                ? root.batteryPct + "%"
                : (root.netDownKb > 0
                  ? "↓ " + (root.netDownKb > 1024 ? Math.round(root.netDownKb / 102.4) / 10 + "M" : root.netDownKb + "K")
                  : "Online")
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
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Style.space(12)
        width: Style.space(496)
        height: Style.space(496)
        spacing: Style.space(10)
        opacity: root.isExpanded ? 1 : 0
        enabled: root.isExpanded
        visible: root.isExpanded || opacity > 0.01
        Behavior on opacity {
          NumberAnimation {
            duration: Style.duration(root.isExpanded ? 220 : 140)
            easing.type: Easing.OutCubic
          }
        }

        // Section identity and live clock
        RowLayout {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(38)
          spacing: Style.space(10)

          Rectangle {
            Layout.preferredWidth: Style.space(36)
            Layout.preferredHeight: Style.space(36)
            radius: Style.space(12)
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
            border.width: 1
            Text {
              anchors.centerIn: parent
              text: root.activeSectionIcon
              color: root.accent
              font.pixelSize: Style.space(20)
              font.weight: Font.DemiBold
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(1)
            Text {
              Layout.fillWidth: true
              text: root.activeSectionTitle
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.space(15)
              font.weight: Font.DemiBold
              color: root.capsuleInk
            }
            Text {
              Layout.fillWidth: true
              text: root.activeSectionSubtitle
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: Style.font.family
              font.pixelSize: Style.space(10)
              color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.58)
            }
          }

          Rectangle {
            Layout.preferredWidth: Style.space(82)
            Layout.preferredHeight: Style.space(30)
            radius: Style.space(15)
            color: Qt.rgba(1, 1, 1, 0.055)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)
              Rectangle {
                Layout.preferredWidth: Style.space(6)
                Layout.preferredHeight: Style.space(6)
                radius: width / 2
                color: root.isPlaying ? "#54d6a0" : root.accent
              }
              Text {
                text: root.clockLabel
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                font.weight: Font.DemiBold
                color: root.capsuleInk
              }
            }
          }
        }

        // Top Navigation Header (Capsule handle + 6 Tabs)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Rectangle {
            Layout.preferredWidth: Style.space(32)
            Layout.preferredHeight: Style.space(26)
            radius: Style.space(7)
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
            spacing: Style.space(3)
            Repeater {
              model: [
                { key: "home", label: "Home", icon: "⌂" },
                { key: "music", label: "Music", icon: "♫" },
                { key: "timer", label: "Focus", icon: "⏱️" },
                { key: "agents", label: "AI", icon: "🤖" },
                { key: "stats", label: "Stats", icon: "📊" },
                { key: "shelf", label: "Shelf", icon: "📋" },
                { key: "system", label: "Sys", icon: "🎛️" }
              ]
              Rectangle {
                id: tabBtn
                required property var modelData
                property bool hovered: false
                Layout.fillWidth: true
                height: Style.space(42)
                radius: Style.space(12)
                color: root.activeTab === tabBtn.modelData.key
                  ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                  : (tabBtn.hovered ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(1, 1, 1, 0.025))
                border.color: root.activeTab === tabBtn.modelData.key
                  ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.48)
                  : Qt.rgba(1, 1, 1, tabBtn.hovered ? 0.12 : 0.045)
                border.width: 1
                Behavior on color { ColorAnimation { duration: Style.duration(140); easing.type: Easing.InOutQuad } }
                Behavior on border.color { ColorAnimation { duration: Style.duration(140); easing.type: Easing.InOutQuad } }

                Column {
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tabBtn.modelData.icon
                    color: root.activeTab === tabBtn.modelData.key ? root.accent : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.76)
                    font.pixelSize: Style.space(14)
                    Behavior on color { ColorAnimation { duration: Style.duration(140); easing.type: Easing.InOutQuad } }
                  }
                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tabBtn.modelData.label
                    color: root.activeTab === tabBtn.modelData.key ? root.capsuleInk : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.56)
                    font.family: Style.font.family
                    font.pixelSize: Style.space(9)
                    font.weight: root.activeTab === tabBtn.modelData.key ? Font.DemiBold : Font.Normal
                  }
                }

                Rectangle {
                  anchors.horizontalCenter: parent.horizontalCenter
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(3)
                  width: root.activeTab === tabBtn.modelData.key ? Style.space(18) : Style.space(4)
                  height: Style.space(2)
                  radius: height / 2
                  color: root.activeTab === tabBtn.modelData.key ? root.accent : Qt.rgba(1, 1, 1, 0.18)
                  opacity: root.activeTab === tabBtn.modelData.key ? 1 : (tabBtn.hovered ? 0.8 : 0)
                  Behavior on width { NumberAnimation { duration: Style.duration(160); easing.type: Easing.OutCubic } }
                  Behavior on opacity { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  hoverEnabled: true
                  onEntered: tabBtn.hovered = true
                  onExited: tabBtn.hovered = false
                  onClicked: root.activeTab = tabBtn.modelData.key
                }
              }
            }
          }
        }

        // ================= TAB 0: HOME OVERVIEW =================
        IslandComponents.HomeOverview {
          visible: root.activeTab === "home"
          opacity: visible ? root.tabContentOpacity : 0
          enabled: visible
          transform: Translate { x: root.tabContentX }
          Layout.fillWidth: true
          Layout.fillHeight: true
          accent: root.accent
          foreground: root.capsuleInk
          mutedForeground: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.58)
          hasTrack: root.hasTrack
          isPlaying: root.isPlaying
          canPlayPause: root.currentPlayer ? root.currentPlayer.canTogglePlaying === true : false
          canGoPrevious: root.currentPlayer ? root.currentPlayer.canGoPrevious === true : false
          canGoNext: root.currentPlayer ? root.currentPlayer.canGoNext === true : false
          mediaTitle: root.mediaTitle
          mediaArtist: root.mediaArtist
          playerName: root.playerName
          timerActive: root.timerActive
          timerRunning: root.timerRunning
          timerLeft: root.timerLeft
          timerName: root.timerName
          availableAgents: root.availableAgentCount()
          batteryAvailable: root.batteryAvailable
          batteryPct: root.batteryPct
          batteryStatus: root.batteryStatus
          systemVolume: root.systemVolume
          systemMuted: root.systemMuted
          nightlightEnabled: root.nightlightEnabled
          idleEnabled: root.idleEnabled
          onNavigate: function(page) { root.activeTab = page }
          onActionRequested: function(action) {
            if (action === "media-previous") root.mediaAction("previous")
            else if (action === "media-toggle") root.mediaAction("play-pause")
            else if (action === "media-next") root.mediaAction("next")
            else if (action === "focus-toggle") {
              if (root.timerActive) root.toggleTimer()
              else root.startTimer(25, "Focus session", "focus")
            } else if (action === "toggle-mute") root.toggleSystemMute()
            else if (action === "toggle-nightlight") root.toggleNightlight()
            else if (action === "screenshot") root.takeScreenshot()
            else if (action === "toggle-idle") root.toggleIdle()
            else if (action === "open-shelf") root.activeTab = "shelf"
          }
        }

        // ================= TAB 1: MUSIC =================
        ColumnLayout {
          visible: root.activeTab === "music"
          opacity: visible ? root.tabContentOpacity : 0
          enabled: visible
          transform: Translate { x: root.tabContentX }
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(12)

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
                  && !Style.reduceMotion
                  loops: Animation.Infinite
                  from: 0; to: 360; duration: Style.duration(4000)
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

          // Seek Progress Bar
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
                Behavior on width { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
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

          // Controls
          RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Style.space(24)
            Repeater {
              model: ["previous", "play-pause", "next"]
              Rectangle {
                id: mediaCtrlBtn
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
                  text: mediaCtrlBtn.modelData === "previous" ? "⏮" : mediaCtrlBtn.modelData === "next" ? "⏭" : root.isPlaying ? "⏸" : "▶"
                  color: mediaCtrlBtn.available ? (mediaCtrlBtn.primary ? "#08080a" : root.capsuleInk) : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.25)
                  font.pixelSize: mediaCtrlBtn.primary ? Style.font.title : Style.font.body
                  font.weight: Font.DemiBold
                }
                MouseArea {
                  anchors.fill: parent
                  enabled: mediaCtrlBtn.available
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: root.mediaAction(mediaCtrlBtn.modelData)
                }
              }
            }
          }

          // Player Selector Chips
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
              Text { anchors.centerIn: parent; text: "Auto"; font.family: Style.font.family; font.pixelSize: Style.font.caption; color: root.capsuleInk }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectPlayer(null) }
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
          opacity: visible ? root.tabContentOpacity : 0
          enabled: visible
          transform: Translate { x: root.tabContentX }
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

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
          opacity: visible ? root.tabContentOpacity : 0
          enabled: visible
          transform: Translate { x: root.tabContentX }
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(8)

          // Interactive Pending Permission Card (if any)
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(64)
            radius: Style.space(10)
            color: Qt.rgba(0.96, 0.62, 0.04, 0.14)
            border.color: "#f59e0b"
            visible: root.agentPendingRequest !== null

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)
              Text { text: "⚠️"; font.pixelSize: Style.font.title }
              ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: root.agentPendingRequest ? (root.agentPendingRequest.agent + " asks permission") : ""; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                Text { text: root.agentPendingRequest ? root.agentPendingRequest.title : ""; font.pixelSize: Style.space(10); elide: Text.ElideRight; color: "#f59e0b" }
              }
              Row {
                spacing: Style.space(6)
                Controls.Button {
                  text: "Allow"
                  onClicked: root.resolveAgentPermission("allow")
                  background: Rectangle { radius: Style.space(6); color: "#10b981" }
                  contentItem: Text { text: "Allow"; font.pixelSize: Style.space(11); font.weight: Font.Bold; color: "#064e3b" }
                }
                Controls.Button {
                  text: "Deny"
                  onClicked: root.resolveAgentPermission("deny")
                  background: Rectangle { radius: Style.space(6); color: Qt.rgba(1, 1, 1, 0.1) }
                  contentItem: Text { text: "Deny"; font.pixelSize: Style.space(11); color: root.capsuleInk }
                }
              }
            }
          }

          // Quick Prompt Bar
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Controls.TextField {
              id: agentPromptField
              Layout.fillWidth: true
              placeholderText: "Quick prompt: e.g. review code or fix memory..."
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
              Layout.preferredWidth: Style.space(60)
              Layout.preferredHeight: Style.space(30)
              radius: Style.space(7)
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
            spacing: Style.space(5)

            Rectangle {
              Layout.fillWidth: true
              height: Style.space(42)
              radius: Style.space(9)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                Text { text: "🤖"; font.pixelSize: Style.font.caption }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                  Text { text: "Google Antigravity"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { text: root.agentsData.antigravity && root.agentsData.antigravity.active ? "● Active Session" : "Installed & Ready"; font.pixelSize: Style.space(9); color: root.agentsData.antigravity && root.agentsData.antigravity.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
                Rectangle { width: Style.space(56); height: Style.space(22); radius: Style.space(5); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                  Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.space(10); color: root.capsuleInk; font.weight: Font.DemiBold }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("agy") } }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: Style.space(42)
              radius: Style.space(9)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                Text { text: "⚡"; font.pixelSize: Style.font.caption }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                  Text { text: "Claude Code"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { text: root.agentsData.claude_code && root.agentsData.claude_code.active ? "● Active Session" : "Installed & Ready"; font.pixelSize: Style.space(9); color: root.agentsData.claude_code && root.agentsData.claude_code.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
                Rectangle { width: Style.space(56); height: Style.space(22); radius: Style.space(5); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                  Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.space(10); color: root.capsuleInk; font.weight: Font.DemiBold }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("claude") } }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: Style.space(42)
              radius: Style.space(9)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                Text { text: "💻"; font.pixelSize: Style.font.caption }
                ColumnLayout { Layout.fillWidth: true; spacing: 0
                  Text { text: "Codex CLI"; font.family: Style.font.family; font.pixelSize: Style.font.caption; font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { text: root.agentsData.codex && root.agentsData.codex.active ? "● Active Session" : "Installed & Ready"; font.pixelSize: Style.space(9); color: root.agentsData.codex && root.agentsData.codex.active ? "#34d399" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
                Rectangle { width: Style.space(56); height: Style.space(22); radius: Style.space(5); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                  Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: Style.space(10); color: root.capsuleInk; font.weight: Font.DemiBold }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.launchTerminal("codex") } }
              }
            }
          }

          Text {
            text: "Local Models (llama-swap :18080 · " + root.localModelsList.length + " models)"
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }

          ListView {
            id: localModelsView
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(156)
            Layout.maximumHeight: Style.space(156)
            clip: true
            spacing: Style.space(4)
            model: root.localModelsList
            Controls.ScrollBar.vertical: Controls.ScrollBar {
              policy: Controls.ScrollBar.AsNeeded
            }
            delegate: Rectangle {
              id: modelItemCard
              required property var modelData
              width: parent ? parent.width : 0
              height: Style.space(32)
              radius: Style.space(7)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.08)
              RowLayout {
                anchors.fill: parent; anchors.margins: Style.space(6); spacing: Style.space(8)
                Rectangle {
                  width: Style.space(8); height: Style.space(8); radius: width / 2
                  color: modelItemCard.modelData.status === "loaded" ? "#34d399" : Qt.rgba(1, 1, 1, 0.3)
                }
                Text {
                  Layout.fillWidth: true
                  text: modelItemCard.modelData.id || "Model"
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  color: root.capsuleInk
                }
                Rectangle {
                  width: Style.space(48); height: Style.space(20); radius: Style.space(5)
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                  Text { anchors.centerIn: parent; text: "Chat"; font.pixelSize: Style.space(10); color: root.capsuleInk }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.launchTerminal("curl -s -N http://127.0.0.1:18080/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"" + modelItemCard.modelData.id + "\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello!\"}],\"stream\":true}'")
                    }
                  }
                }
              }
            }
          }
        }

        // ================= TAB 4: HARDWARE STATS =================
        ColumnLayout {
          visible: root.activeTab === "stats"
          opacity: visible ? root.tabContentOpacity : 0
          enabled: visible
          transform: Translate { x: root.tabContentX }
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

          // 4 Hardware Stat Cards
          GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Style.space(8)
            columnSpacing: Style.space(8)

            // CPU
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(64)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              ColumnLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(4)
                RowLayout {
                  Text { text: "⚙️ CPU Usage"; font.family: Style.font.family; font.pixelSize: Style.space(11); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6) }
                  Item { Layout.fillWidth: true }
                  Text { text: (root.hardwareData.cpu ? root.hardwareData.cpu.pct : 0) + "%"; font.bold: true; font.pixelSize: Style.space(12); color: root.capsuleInk }
                }
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(4); radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                  Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.hardwareData.cpu ? root.hardwareData.cpu.pct : 0) / 100))
                    height: parent.height; radius: 2; color: root.accent
                  }
                }
              }
            }

            // RAM
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(64)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              ColumnLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(4)
                RowLayout {
                  Text { text: "🧠 Memory (RAM)"; font.family: Style.font.family; font.pixelSize: Style.space(11); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6) }
                  Item { Layout.fillWidth: true }
                  Text { text: (root.hardwareData.ram ? root.hardwareData.ram.pct : 0) + "%"; font.bold: true; font.pixelSize: Style.space(12); color: root.hardwareData.ram && root.hardwareData.ram.pct > 85 ? "#f87171" : root.capsuleInk }
                }
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(4); radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                  Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.hardwareData.ram ? root.hardwareData.ram.pct : 0) / 100))
                    height: parent.height; radius: 2; color: root.hardwareData.ram && root.hardwareData.ram.pct > 85 ? "#ef4444" : root.accent
                  }
                }
                Text {
                  text: root.hardwareData.ram ? (Math.round(root.hardwareData.ram.used_mb / 102.4) / 10 + " / " + Math.round(root.hardwareData.ram.total_mb / 102.4) / 10 + " GB") : ""
                  font.pixelSize: Style.space(9); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5)
                }
              }
            }

            // Swap
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(64)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              ColumnLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(4)
                RowLayout {
                  Text { text: "💾 Swap Memory"; font.family: Style.font.family; font.pixelSize: Style.space(11); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6) }
                  Item { Layout.fillWidth: true }
                  Text { text: (root.hardwareData.swap ? root.hardwareData.swap.pct : 0) + "%"; font.bold: true; font.pixelSize: Style.space(12); color: root.capsuleInk }
                }
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(4); radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                  Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.hardwareData.swap ? root.hardwareData.swap.pct : 0) / 100))
                    height: parent.height; radius: 2; color: "#38bdf8"
                  }
                }
                Text {
                  text: root.hardwareData.swap ? (Math.round(root.hardwareData.swap.used_mb / 102.4) / 10 + " / " + Math.round(root.hardwareData.swap.total_mb / 102.4) / 10 + " GB") : ""
                  font.pixelSize: Style.space(9); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5)
                }
              }
            }

            // GPU VRAM
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(64)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              ColumnLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(4)
                RowLayout {
                  Text { text: "🎮 GPU VRAM"; font.family: Style.font.family; font.pixelSize: Style.space(11); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6) }
                  Item { Layout.fillWidth: true }
                  Text { text: (root.hardwareData.gpu ? root.hardwareData.gpu.temp_c : 0) + "°C"; font.bold: true; font.pixelSize: Style.space(12); color: "#34d399" }
                }
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(4); radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                  Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.hardwareData.gpu && root.hardwareData.gpu.total_mb > 0 ? root.hardwareData.gpu.used_mb / root.hardwareData.gpu.total_mb : 0)))
                    height: parent.height; radius: 2; color: "#a855f7"
                  }
                }
                Text {
                  text: root.hardwareData.gpu ? (root.hardwareData.gpu.used_mb + " / " + root.hardwareData.gpu.total_mb + " MB (" + root.hardwareData.gpu.name.replace("NVIDIA GeForce ", "") + ")") : ""
                  font.pixelSize: Style.space(9); elide: Text.ElideRight; color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5)
                }
              }
            }

            // Network Traffic
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(64)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              ColumnLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(4)
                RowLayout {
                  Text { text: "🌐 Network Traffic"; font.family: Style.font.family; font.pixelSize: Style.space(11); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6) }
                  Item { Layout.fillWidth: true }
                  Text {
                    text: root.netDownKb > 1024 ? (Math.round(root.netDownKb / 102.4) / 10 + " MB/s") : (root.netDownKb + " KB/s")
                    font.bold: true; font.pixelSize: Style.space(12); color: "#06b6d4"
                  }
                }
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(4); radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                  Rectangle {
                    width: parent.width * Math.max(0.04, Math.min(1, root.netDownKb / 5000))
                    height: parent.height; radius: 2; color: "#06b6d4"
                  }
                }
                Text {
                  text: "↓ " + root.netDownKb + " KB/s  ·  ↑ " + root.netUpKb + " KB/s"
                  font.pixelSize: Style.space(9); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5)
                }
              }
            }

            // Disk Storage
            Rectangle {
              Layout.fillWidth: true
              height: Style.space(64)
              radius: Style.space(10)
              color: root.glass
              border.color: Qt.rgba(1, 1, 1, 0.1)
              ColumnLayout {
                anchors.fill: parent; anchors.margins: Style.space(8); spacing: Style.space(4)
                RowLayout {
                  Text { text: "💽 Root Storage"; font.family: Style.font.family; font.pixelSize: Style.space(11); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6) }
                  Item { Layout.fillWidth: true }
                  Text { text: String(root.diskData.pct || "0%"); font.bold: true; font.pixelSize: Style.space(12); color: root.capsuleInk }
                }
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(4); radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                  Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (parseInt(root.diskData.pct) || 0) / 100))
                    height: parent.height; radius: 2; color: (parseInt(root.diskData.pct) || 0) > 90 ? "#ef4444" : "#10b981"
                  }
                }
                Text {
                  text: Math.round(Number(root.diskData.used_mb || 0) / 1024) + " / " + Math.round(Number(root.diskData.total_mb || 0) / 1024) + " GB (" + (root.diskData.pct || "0%") + " used)"
                  font.pixelSize: Style.space(9); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5)
                }
              }
            }
          }

          // Memory Optimizer Action
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(46)
            radius: Style.space(10)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)
            RowLayout {
              anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(10)
              Text { text: "⚡"; font.pixelSize: Style.font.body }
              ColumnLayout { Layout.fillWidth: true; spacing: 0
                Text { text: "Clean Caches & Optimize RAM"; font.weight: Font.DemiBold; font.pixelSize: Style.space(11); color: root.capsuleInk }
                Text { text: "Flushes page caches & syncs dirty pages to disk"; font.pixelSize: Style.space(9); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) } }
              Controls.Button {
                text: "Optimize"
                onClicked: root.optimizeMemory()
                background: Rectangle { radius: Style.space(6); color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) }
                contentItem: Text { text: "Optimize"; font.pixelSize: Style.space(10); font.bold: true; color: root.capsuleInk }
              }
            }
          }

          Item { Layout.fillHeight: true }
        }

        // ================= TAB 5: SHELF & CLIPBOARD =================
        ColumnLayout {
          visible: root.activeTab === "shelf"
          opacity: visible ? root.tabContentOpacity : 0
          enabled: visible
          transform: Translate { x: root.tabContentX }
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(10)

          // Live Clipboard Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(100)
            radius: Style.space(12)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)
            clip: true

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(4)

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

              Image {
                visible: root.clipboardData.type === "image" && root.clipboardData.image_path !== ""
                Layout.fillWidth: true
                Layout.fillHeight: true
                source: visible ? "file://" + root.clipboardData.image_path : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }

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

          // Trash Guard Banner
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(34)
            radius: Style.space(8)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(8)

              Text {
                text: root.trashItemsCount > 0 ? "🗑️" : "✨"
                font.pixelSize: Style.space(12)
              }
              Text {
                Layout.fillWidth: true
                text: root.trashItemsCount > 0
                  ? root.trashItemsCount + " item" + (root.trashItemsCount === 1 ? "" : "s") + " in Trash"
                  : "Trash is clean"
                font.family: Style.font.family
                font.pixelSize: Style.space(11)
                color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.7)
              }
              Controls.Button {
                visible: root.trashItemsCount > 0
                text: "Empty"
                onClicked: root.emptyTrash()
                background: Rectangle {
                  radius: Style.space(5)
                  color: Qt.rgba(0.94, 0.27, 0.27, 0.2)
                  border.color: "#ef4444"
                }
                contentItem: Text { text: "Empty"; font.pixelSize: Style.space(9); font.bold: true; color: "#fca5a5" }
              }
            }
          }

          // Recent Screenshots
          Text {
            text: "Recent Screenshots"
            font.family: Style.font.family
            font.pixelSize: Style.space(11)
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Repeater {
              model: root.recentScreenshots
              Rectangle {
                id: shotThumbCard
                required property var modelData
                Layout.fillWidth: true
                height: Style.space(48)
                radius: Style.space(8)
                color: root.glass
                border.color: Qt.rgba(1, 1, 1, 0.1)
                clip: true

                Image {
                  anchors.fill: parent
                  source: "file://" + shotThumbCard.modelData.path
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openFile(shotThumbCard.modelData.path)
                }
              }
            }
          }

          // Scratchpad
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
            radius: Style.space(10)
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
                font.pixelSize: Style.space(11)
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

        // ================= TAB 6: SYSTEM & CONTROLS =================
        ColumnLayout {
          visible: root.activeTab === "system"
          opacity: visible ? root.tabContentOpacity : 0
          enabled: visible
          transform: Translate { x: root.tabContentX }
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(8)

          // 1. Audio Volume Slider Card
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(44)
            radius: Style.space(9)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(26); height: Style.space(26); radius: Style.space(6)
                color: root.systemMuted ? "#ef4444" : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                Text {
                  anchors.centerIn: parent
                  text: root.systemMuted ? "🔇" : root.systemVolume < 50 ? "🔉" : "🔊"
                  font.pixelSize: Style.space(11)
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleSystemMute()
                }
              }

              Rectangle {
                id: volTrack
                Layout.fillWidth: true
                height: Style.space(6)
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
            height: Style.space(44)
            radius: Style.space(9)
            color: root.glass
            border.color: Qt.rgba(1, 1, 1, 0.1)

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(26); height: Style.space(26); radius: Style.space(6)
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                Text { anchors.centerIn: parent; text: "☀️"; font.pixelSize: Style.space(11) }
              }

              Rectangle {
                id: brightTrack
                Layout.fillWidth: true
                height: Style.space(6)
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

          // 3. Top Position Presets (Auto / Flush 0px / Snug 2px / Floating 6px)
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Text {
              text: "Position:"
              font.pixelSize: Style.space(10)
              color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.6)
            }
            Repeater {
              model: [
                { mode: "auto", label: "Auto (Bar Detect)" },
                { mode: "flush", label: "Flush (0px)" },
                { mode: "snug", label: "Snug (2px)" },
                { mode: "floating", label: "Float (6px)" }
              ]
              Controls.Button {
                id: posPresetBtn
                required property var modelData
                Layout.fillWidth: true
                text: posPresetBtn.modelData.label
                onClicked: {
                  root.positionMode = posPresetBtn.modelData.mode
                  root.persistState()
                }
                background: Rectangle {
                  radius: Style.space(6)
                  color: root.positionMode === posPresetBtn.modelData.mode ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass
                  border.color: root.positionMode === posPresetBtn.modelData.mode ? root.accent : Qt.rgba(1, 1, 1, 0.1)
                }
                contentItem: Text { text: posPresetBtn.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: Style.space(9); font.weight: root.positionMode === posPresetBtn.modelData.mode ? Font.DemiBold : Font.Normal; color: root.capsuleInk }
              }
            }
          }

          // 4. System Updates Banner
          Rectangle {
            Layout.fillWidth: true
            height: Style.space(32)
            radius: Style.space(7)
            color: root.systemUpdatesCount > 0 ? Qt.rgba(0.96, 0.62, 0.04, 0.12) : root.glass
            border.color: root.systemUpdatesCount > 0 ? "#f59e0b" : Qt.rgba(1, 1, 1, 0.1)

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: root.systemUpdatesCount > 0 ? "📦" : "✨"
                font.pixelSize: Style.space(11)
              }
              Text {
                Layout.fillWidth: true
                text: root.systemUpdatesCount > 0
                  ? root.systemUpdatesCount + " update" + (root.systemUpdatesCount === 1 ? "" : "s") + " available · review before install"
                  : "Arch & Omarchy Packages Up to Date"
                font.family: Style.font.family
                font.pixelSize: Style.space(10)
                font.weight: root.systemUpdatesCount > 0 ? Font.DemiBold : Font.Normal
                color: root.systemUpdatesCount > 0 ? "#fbbf24" : Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.7)
              }
              Controls.Button {
                text: "Check"
                onClicked: root.checkUpdates()
                background: Rectangle { radius: Style.space(5); color: Qt.rgba(1, 1, 1, 0.08) }
                contentItem: Text { text: "Check"; font.pixelSize: Style.space(9); color: root.capsuleInk }
              }
            }
          }

          // 5. Workspaces Row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)
            Repeater {
              model: Hyprland.workspaces.values
              Rectangle {
                id: wsCard
                required property var modelData
                Layout.fillWidth: true
                height: Style.space(32)
                radius: Style.space(7)
                color: wsCard.modelData.focused ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass
                border.color: wsCard.modelData.focused ? root.accent : Qt.rgba(1, 1, 1, 0.1)
                Column {
                  anchors.centerIn: parent; spacing: 1
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: wsCard.modelData.name || String(wsCard.modelData.id); font.family: Style.font.family; font.pixelSize: Style.space(10); font.weight: Font.DemiBold; color: root.capsuleInk }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: (wsCard.modelData.toplevels ? wsCard.modelData.toplevels.values.length : 0) + " win"; font.pixelSize: Style.space(8); color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.5) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { wsCard.modelData.activate(); root.isExpanded = false } }
              }
            }
          }

          // 6. Connectivity & Hardware Radios Row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Controls.Button {
              Layout.fillWidth: true
              text: root.connectivityData.wifi ? "📶 WiFi On" : "📶 WiFi Off"
              onClicked: root.toggleWifi()
              background: Rectangle {
                radius: Style.space(7)
                color: root.connectivityData.wifi ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) : root.glass
                border.color: root.connectivityData.wifi ? root.accent : Qt.rgba(1, 1, 1, 0.1)
              }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(10); color: root.capsuleInk }
            }

            Controls.Button {
              Layout.fillWidth: true
              text: root.connectivityData.bluetooth ? "ᛒ BT On" : "ᛒ BT Off"
              onClicked: root.toggleBluetooth()
              background: Rectangle {
                radius: Style.space(7)
                color: root.connectivityData.bluetooth ? Qt.rgba(0.22, 0.55, 0.95, 0.22) : root.glass
                border.color: root.connectivityData.bluetooth ? "#3b82f6" : Qt.rgba(1, 1, 1, 0.1)
              }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(10); color: root.capsuleInk }
            }

            Controls.Button {
              Layout.fillWidth: true
              text: root.nightlightEnabled ? "🌙 Night On" : "🌙 Night"
              onClicked: root.toggleNightlight()
              background: Rectangle { radius: Style.space(7); color: root.nightlightEnabled ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass; border.color: root.nightlightEnabled ? root.accent : Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(10); color: root.capsuleInk }
            }

            Controls.Button {
              Layout.fillWidth: true
              text: root.idleEnabled ? "☕ Awake" : "☕ Sleep"
              onClicked: root.toggleIdle()
              background: Rectangle { radius: Style.space(7); color: root.idleEnabled ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : root.glass; border.color: root.idleEnabled ? root.accent : Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(10); color: root.capsuleInk }
            }
          }

          // 7. System Desktop Quick Actions
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Controls.Button {
              Layout.fillWidth: true
              text: "▧ Wallpaper"
              onClicked: root.nextOmarchyBackground()
              background: Rectangle { radius: Style.space(7); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(10); color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "◐ Theme"
              onClicked: root.openOmarchyThemeSwitcher()
              background: Rectangle { radius: Style.space(7); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(10); color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "📸 Shot"
              onClicked: root.takeScreenshot()
              background: Rectangle { radius: Style.space(7); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(10); color: root.capsuleInk }
            }
            Controls.Button {
              Layout.fillWidth: true
              text: "🔒 Lock"
              onClicked: root.lockSession()
              background: Rectangle { radius: Style.space(7); color: root.glass; border.color: Qt.rgba(1, 1, 1, 0.1) }
              contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Style.font.family; font.pixelSize: Style.space(10); color: root.capsuleInk }
            }
          }
        }
      }
    }

    // SPLIT SATELLITE BUBBLE (Timer / Stopwatch active while music plays)
    Rectangle {
      id: timerSatellite
      z: 2
      readonly property bool shown: !root.isExpanded && !root.isPeeking && root.agentPendingRequest === null && root.hasTrack && (root.timerActive || root.stopwatchVisible)
      visible: shown || opacity > 0.01
      enabled: shown
      opacity: shown ? 1 : 0
      Behavior on opacity {
        NumberAnimation {
          duration: Style.duration(timerSatellite.shown ? 140 : 90)
          easing.type: Easing.OutCubic
        }
      }
      anchors.left: morphCard.right
      anchors.leftMargin: Style.space(6)
      y: root.effectiveTopOffset
      Behavior on y {
        NumberAnimation {
          duration: Style.duration(root.isExpanded ? 240 : 160)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }
      width: Style.space(78)
      height: Style.space(34)
      radius: height / 2

      gradient: Gradient {
        GradientStop { position: 0.0; color: "#18181c" }
        GradientStop { position: 0.25; color: "#09090d" }
        GradientStop { position: 1.0; color: "#020204" }
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
