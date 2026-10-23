import QtQuick
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
  property var bar: null
  property var settings: null

  readonly property string scriptPath:
    Qt.resolvedUrl("island-backend.sh").toString().replace(/^file:\/\//, "")
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property var mediaPlayers: Mpris.players.values
  readonly property var focusedWorkspace: Hyprland.focusedWorkspace
  readonly property int workspaceId: focusedWorkspace ? focusedWorkspace.id : 0
  readonly property int workspaceWindows: focusedWorkspace
    ? focusedWorkspace.toplevels.values.length : 0

  // Liquid Glass True-Black Palette
  readonly property color capsuleSurface: "#060608"
  readonly property color capsuleInk: "#f8f9fa"
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
  readonly property bool timerActive: panelLoader.item
    ? panelLoader.item.timerTotal > 0 && !panelLoader.item.timerFinished : false
  readonly property bool stopwatchVisible: panelLoader.item
    ? panelLoader.item.stopwatchRunning || panelLoader.item.stopwatchElapsed > 0 : false
  readonly property int timerLeft: panelLoader.item ? panelLoader.item.timerLeft : 0
  readonly property bool isPinned: panelLoader.item ? panelLoader.item.pinIsland : false

  property var selectedPlayer: null
  property bool capsuleHovered: false
  property bool hoverExpanded: false
  property bool panelHovered: panelLoader.item ? panelLoader.item.pointerInside : false
  property int batteryPct: -1
  property string batteryStatus: "Unavailable"
  property bool batteryAvailable: false
  property bool isRecording: false
  property string clockLabel: Qt.formatTime(new Date(), "h:mm")

  property int volumeHudLevel: -1
  property bool showVolumeHud: false

  function cleanArtUrl(raw) {
    if (!raw || typeof raw !== "string") return ""
    var trimmed = raw.trim()
    if (trimmed === "") return ""
    if (trimmed.startsWith("file://") || trimmed.startsWith("http://") || trimmed.startsWith("https://")) return trimmed
    if (trimmed.startsWith("/")) return "file://" + trimmed
    return ""
  }

  // Virtual bar geometry for KeyboardPanel popup anchoring
  QtObject {
    id: panelBarAnchor
    readonly property string position: "top"
    readonly property int barSize: Style.space(60)
    readonly property string fontFamily: Style.font.family
    readonly property color foreground: Commons.Color.foreground
    readonly property color barForeground: Commons.Color.foreground
    property var activePopout: null
    readonly property var clickTargets: []
    function requestPopout(owner) { activePopout = owner }
    function releasePopout(owner) { if (activePopout === owner) activePopout = null }
    function switchPanelFrom(owner, direction) { return false }
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

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function openTimer() { if (panelLoader.item) panelLoader.item.openPage("timer") }
  function openDesk() { if (panelLoader.item) panelLoader.item.openPage("desk") }
  function openAgents() { if (panelLoader.item) panelLoader.item.openPage("agents") }

  function cycleWorkspace(direction) {
    var desktops = []
    var available = Hyprland.workspaces.values
    for (var i = 0; i < available.length; ++i) {
      if (available[i] && available[i].id > 0) desktops.push(available[i])
    }
    desktops.sort(function(a, b) { return a.id - b.id })
    if (desktops.length < 2) return

    var current = -1
    for (var j = 0; j < desktops.length; ++j) {
      if (desktops[j].id === root.workspaceId) { current = j; break }
    }
    if (current < 0) return

    var next = (current + direction + desktops.length) % desktops.length
    desktops[next].activate()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = panelBarAnchor
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = islandCapsule
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refreshTelemetry() {
    if (telemetryProc.running) return
    telemetryProc.command = ["bash", scriptPath, "get"]
    telemetryProc.running = true
  }

  implicitWidth: islandRow.implicitWidth
  implicitHeight: islandRow.height
  Behavior on implicitWidth {
    SpringAnimation { spring: 3.8; damping: 0.32; mass: 0.8 }
  }
  Behavior on implicitHeight {
    SpringAnimation { spring: 4.0; damping: 0.34; mass: 0.8 }
  }
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Connections {
    target: Mpris.players
    function onObjectRemovedPost(player, index) {
      if (root.selectedPlayer === player) root.selectedPlayer = null
    }
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
          if (data.agents && panelLoader.item) {
            panelLoader.item.agentsData = data.agents
          }
        } catch (e) {}
      }
    }
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
    onTriggered: root.clockLabel = Qt.formatTime(new Date(), "h:mm")
  }

  Component.onCompleted: root.refreshTelemetry()

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

  Row {
    id: islandRow
    height: islandCapsule.height
    spacing: Style.space(4)

    // Workspace Satellite
    Rectangle {
      id: workspaceBubble
      visible: width > 0.5
      width: root.hoverExpanded && !root.hasTrack ? Style.space(44) : 0
      height: width > 0 ? Style.space(44) : 0
      radius: height / 2
      color: "#08080a"
      border.color: Qt.rgba(1, 1, 1, 0.12)
      border.width: 0.9
      scale: width > 0 ? 1 : 0.84
      Behavior on width { SpringAnimation { spring: 3.8; damping: 0.32; mass: 0.8 } }
      Behavior on height { SpringAnimation { spring: 4.0; damping: 0.34; mass: 0.8 } }
      Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.38; mass: 0.8 } }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openDesk()
        onWheel: function(wheel) {
          if (wheel.angleDelta.y !== 0)
            root.cycleWorkspace(wheel.angleDelta.y > 0 ? -1 : 1)
        }
      }
      Text {
        anchors.centerIn: parent
        text: root.workspaceId > 0 ? String(root.workspaceId) : "·"
        color: root.capsuleInk
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.space(16)
        font.weight: Font.DemiBold
      }
    }

    // Screen Recording Satellite
    Rectangle {
      id: recBubble
      visible: root.isRecording || width > 0.5
      width: root.isRecording ? Style.space(58) : 0
      height: islandCapsule.height
      radius: height / 2
      color: "#1c0909"
      border.color: "#ef4444"
      border.width: 1
      clip: true
      scale: root.isRecording ? 1 : 0.84
      Behavior on width { SpringAnimation { spring: 4.0; damping: 0.35; mass: 0.75 } }
      Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.38; mass: 0.8 } }

      Row {
        anchors.centerIn: parent
        spacing: Style.space(5)
        Rectangle {
          width: Style.space(7)
          height: Style.space(7)
          radius: width / 2
          color: "#ef4444"
          anchors.verticalCenter: parent.verticalCenter
          SequentialAnimation on opacity {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { to: 0.2; duration: 600 }
            NumberAnimation { to: 1.0; duration: 600 }
          }
        }
        Text {
          text: "REC"
          color: "#fca5a5"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.space(11)
          font.weight: Font.Bold
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    // Main Liquid Glass Capsule
    Rectangle {
      id: islandCapsule
      height: root.hoverExpanded ? Style.space(52) : Style.space(34)
      width: root.showVolumeHud
        ? Style.space(170)
        : (root.hasTrack
          ? Math.min(Style.space(360), Style.space(160)
              + Math.max(trackTitle.implicitWidth, trackArtist.implicitWidth)
              + ((root.capsuleHovered || root.hoverExpanded) ? Style.space(60) : 0))
          : (root.opened ? Style.space(150) : (root.hoverExpanded ? Style.space(240) : Style.space(130))))
      radius: height / 2

      gradient: Gradient {
        GradientStop { position: 0.0; color: "#1c1c20" }
        GradientStop { position: 0.26; color: "#09090b" }
        GradientStop { position: 1.0; color: "#030304" }
      }

      border.color: root.opened
        ? Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.75)
        : Qt.rgba(1, 1, 1, root.hoverExpanded ? 0.16 : 0.10)
      border.width: 0.9
      clip: true

      Behavior on width {
        SpringAnimation { spring: 3.8; damping: 0.32; mass: 0.8 }
      }
      Behavior on height {
        SpringAnimation { spring: 4.0; damping: 0.34; mass: 0.8 }
      }
      scale: capsuleMouse.pressed ? 0.97
        : ((root.capsuleHovered || root.hoverExpanded) ? 1.015 : 1.0)
      Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.38; mass: 0.8 } }
      Behavior on border.color { ColorAnimation { duration: 180 } }

      // Top Specular Highlight Edge
      Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1.5
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - Style.space(36))
        height: 1.2
        radius: 0.6
        color: root.capsuleInk
        opacity: root.hoverExpanded ? 0.28 : 0.12
        Behavior on opacity { NumberAnimation { duration: 180 } }
      }

      // Volume HUD Content
      RowLayout {
        anchors.centerIn: parent
        spacing: Style.space(8)
        visible: root.showVolumeHud

        Text {
          text: root.volumeHudLevel === 0 ? "🔇" : root.volumeHudLevel < 50 ? "🔉" : "🔊"
          font.pixelSize: Style.font.body
          color: Commons.Color.accent
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
            color: Commons.Color.accent
          }
        }

        Text {
          text: root.volumeHudLevel + "%"
          color: root.capsuleInk
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
        }
      }

      // Track Content Row
      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(9)
        anchors.rightMargin: (root.capsuleHovered || root.hoverExpanded) ? Style.space(62) : Style.space(11)
        spacing: Style.space(7)
        visible: !root.showVolumeHud

        // Album Art / Vinyl Disc
        Rectangle {
          Layout.preferredWidth: Style.space(26)
          Layout.preferredHeight: Style.space(26)
          radius: Style.space(8)
          color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.16)
          clip: true
          visible: root.hasTrack

          Image {
            id: albumArtThumb
            anchors.fill: parent
            visible: root.hasTrack && root.artUrl !== "" && status !== Image.Error
            source: visible ? root.artUrl : ""
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }

          // Rotating Vinyl Disc Fallback
          Rectangle {
            anchors.centerIn: parent
            width: Style.space(22)
            height: Style.space(22)
            radius: width / 2
            color: "#111114"
            border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.5)
            border.width: 1
            visible: !albumArtThumb.visible

            RotationAnimation on rotation {
              running: root.isPlaying
              loops: Animation.Infinite
              from: 0
              to: 360
              duration: 4000
            }

            Rectangle {
              anchors.centerIn: parent
              width: Style.space(7)
              height: Style.space(7)
              radius: width / 2
              color: Commons.Color.accent
            }
          }
        }

        // Track Details
        ColumnLayout {
          id: trackDetails
          Layout.fillWidth: true
          visible: root.hasTrack
          spacing: 0

          Text {
            id: trackTitle
            Layout.fillWidth: true
            text: root.mediaTitle
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: Font.DemiBold
            color: root.capsuleInk
          }

          Text {
            id: trackArtist
            Layout.fillWidth: true
            text: root.mediaArtist || root.playerName
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.space(10)
            color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.65)
          }
        }

        // Dancing Equalizer Waves
        Row {
          spacing: Style.space(2)
          visible: root.hasTrack && root.isPlaying
          Layout.alignment: Qt.AlignVCenter
          Repeater {
            model: [
              { minH: 3, maxH: 12, dur1: 320, dur2: 380 },
              { minH: 4, maxH: 16, dur1: 420, dur2: 310 },
              { minH: 3, maxH: 11, dur1: 290, dur2: 360 },
              { minH: 4, maxH: 14, dur1: 440, dur2: 410 }
            ]
            Rectangle {
              required property var modelData
              width: Style.space(2.5)
              height: root.isPlaying ? modelData.maxH : modelData.minH
              radius: Style.space(1.2)
              color: Commons.Color.accent

              SequentialAnimation on height {
                running: root.isPlaying
                loops: Animation.Infinite
                NumberAnimation { to: modelData.minH; duration: modelData.dur1; easing.type: Easing.InOutQuad }
                NumberAnimation { to: modelData.maxH; duration: modelData.dur2; easing.type: Easing.InOutQuad }
              }
              Behavior on height { NumberAnimation { duration: 180 } }
            }
          }
        }

        // Paused Indicator
        Text {
          visible: root.hasTrack && !root.isPlaying
          text: "Ⅱ"
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
          color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.55)
        }

        // Idle State Display
        Text {
          visible: !root.hasTrack
          Layout.fillWidth: true
          text: root.opened ? "Dynamic Island" : root.clockLabel
          horizontalAlignment: Text.AlignHCenter
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.hoverExpanded ? Style.space(15) : Style.space(12)
          font.weight: root.opened ? Font.DemiBold : Font.Medium
          color: root.capsuleInk
        }
      }

      // Bottom Seek Progress Line
      Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: parent.width * (root.duration > 0
          ? Math.max(0, Math.min(1, root.position / root.duration)) : 0)
        height: Style.space(1.5)
        visible: root.isPlaying && root.duration > 0
        color: Commons.Color.accent
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
      }

      // Mouse Area on Capsule
      MouseArea {
        id: capsuleMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.button === Qt.MiddleButton) {
            root.mediaAction("play-pause")
          } else if (mouse.button === Qt.RightButton) {
            root.cyclePlayer()
          } else {
            root.togglePanel()
          }
        }
        onWheel: function(wheel) {
          root.mediaAction(wheel.angleDelta.y > 0 ? "volume-up" : "volume-down")
        }
      }

      HoverHandler {
        onHoveredChanged: root.capsuleHovered = hovered
      }

      // Quick Media Transport Controls on Hover
      Row {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(3)
        visible: root.hasTrack && (root.capsuleHovered || root.hoverExpanded) && !root.showVolumeHud
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Repeater {
          model: [
            { label: root.isPlaying ? "Ⅱ" : "▶", action: "play-pause",
              enabled: root.currentPlayer ? root.currentPlayer.canTogglePlaying : false },
            { label: "›", action: "next",
              enabled: root.currentPlayer ? root.currentPlayer.canGoNext : false }
          ]

          Rectangle {
            required property var modelData
            width: Style.space(22)
            height: Style.space(24)
            radius: Style.space(7)
            color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.16)
            opacity: modelData.enabled ? 1 : 0.35

            Text {
              anchors.centerIn: parent
              text: modelData.label
              color: root.capsuleInk
              font.pixelSize: Style.font.caption
              font.weight: Font.DemiBold
            }

            MouseArea {
              anchors.fill: parent
              enabled: parent.modelData.enabled
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.mediaAction(parent.modelData.action)
            }
          }
        }
      }
    }

    // Timer Satellite Bubble
    Rectangle {
      id: timerBubble
      visible: root.timerActive || width > 0.5
      width: root.timerActive ? Math.max(Style.space(84), timerLabel.implicitWidth + Style.space(38)) : 0
      height: islandCapsule.height
      opacity: root.timerActive ? 1 : 0
      scale: root.timerActive ? 1 : 0.88
      radius: height / 2
      color: root.capsuleSurface
      border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.55)
      border.width: 1
      clip: true

      Behavior on width { SpringAnimation { spring: 4.6; damping: 0.76; mass: 0.7 } }
      Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on scale { SpringAnimation { spring: 5.1; damping: 0.7 } }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(6)
        Text {
          text: panelLoader.item && panelLoader.item.timerRunning ? "Ⅱ" : "▶"
          color: Commons.Color.accent
          font.pixelSize: Style.font.body
        }
        Text {
          id: timerLabel
          Layout.fillWidth: true
          text: panelLoader.item ? panelLoader.item.formatTime(root.timerLeft) : "0:00"
          color: root.capsuleInk
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
        }
      }

      Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: parent.width * (panelLoader.item && panelLoader.item.timerTotal > 0
          ? Math.max(0, Math.min(1, root.timerLeft / panelLoader.item.timerTotal)) : 0)
        height: Style.space(1.5)
        color: Commons.Color.accent
        opacity: 0.9
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.x < Style.space(34) && panelLoader.item) {
            panelLoader.item.toggleTimer()
          } else {
            root.openTimer()
          }
        }
        onWheel: function(wheel) {
          if (panelLoader.item) panelLoader.item.adjustTimer(wheel.angleDelta.y > 0 ? 60 : -60)
        }
      }
    }

    // Stopwatch Satellite Bubble
    Rectangle {
      id: stopwatchBubble
      visible: root.stopwatchVisible || width > 0.5
      width: root.stopwatchVisible ? Math.max(Style.space(90), stopwatchLabel.implicitWidth + Style.space(38)) : 0
      height: islandCapsule.height
      opacity: root.stopwatchVisible ? 1 : 0
      scale: root.stopwatchVisible ? 1 : 0.88
      radius: height / 2
      color: root.capsuleSurface
      border.color: Qt.rgba(root.capsuleInk.r, root.capsuleInk.g, root.capsuleInk.b, 0.20)
      border.width: 1
      clip: true

      Behavior on width { SpringAnimation { spring: 4.6; damping: 0.76; mass: 0.7 } }
      Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on scale { SpringAnimation { spring: 5.1; damping: 0.7 } }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.space(10)
        anchors.rightMargin: Style.space(10)
        spacing: Style.space(6)
        Text {
          text: panelLoader.item && panelLoader.item.stopwatchRunning ? "Ⅱ" : "▶"
          color: Commons.Color.accent
          font.pixelSize: Style.font.caption
        }
        Text {
          id: stopwatchLabel
          Layout.fillWidth: true
          text: panelLoader.item ? panelLoader.item.formatTime(panelLoader.item.stopwatchElapsed) : "0:00"
          color: root.capsuleInk
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.weight: Font.DemiBold
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          if (mouse.x < Style.space(34) && panelLoader.item) {
            panelLoader.item.toggleStopwatch()
          } else {
            root.openTimer()
          }
        }
      }
    }

    // Quick Focus Preset Satellite
    Rectangle {
      id: focusBubble
      visible: width > 0.5
      width: root.hoverExpanded && !root.timerActive && !root.stopwatchVisible
        ? Style.space(52) : 0
      height: width > 0 ? Style.space(52) : 0
      radius: height / 2
      color: "#08080a"
      border.color: Qt.rgba(Commons.Color.accent.r, Commons.Color.accent.g, Commons.Color.accent.b, 0.52)
      border.width: 1
      scale: width > 0 ? 1 : 0.84

      Behavior on width { SpringAnimation { spring: 3.8; damping: 0.32; mass: 0.8 } }
      Behavior on height { SpringAnimation { spring: 4.0; damping: 0.34; mass: 0.8 } }
      Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.38; mass: 0.8 } }

      Text {
        z: 2
        anchors.centerIn: parent
        text: "25m"
        color: root.capsuleInk
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.space(13)
        font.weight: Font.DemiBold
      }

      MouseArea {
        z: 1
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (panelLoader.item) panelLoader.item.startTimer(25, "Focus", "focus")
        }
      }
    }

    // Battery Gauge Satellite
    Rectangle {
      id: batteryBubble
      property real batterySweep: root.batteryPct >= 0
        ? Math.max(0, Math.min(100, root.batteryPct)) * 3.6 : 0
      visible: width > 0.5
      width: root.hoverExpanded && root.batteryAvailable && !root.hasTrack
        && !root.timerActive && !root.stopwatchVisible ? Style.space(46) : 0
      height: width > 0 ? Style.space(46) : 0
      radius: height / 2
      color: "#08080a"
      border.color: root.batteryPct >= 0 && root.batteryPct <= 15
        ? Qt.rgba(1, 0.27, 0.23, 0.72)
        : (root.batteryPct >= 0 && root.batteryPct <= 30
          ? Qt.rgba(1, 0.62, 0.04, 0.72)
          : Qt.rgba(1, 1, 1, 0.14))
      border.width: 0.9
      scale: width > 0 ? 1 : 0.84

      Behavior on width { SpringAnimation { spring: 3.8; damping: 0.32; mass: 0.8 } }
      Behavior on height { SpringAnimation { spring: 4.0; damping: 0.34; mass: 0.8 } }
      Behavior on scale { SpringAnimation { spring: 4.8; damping: 0.38; mass: 0.8 } }
      Behavior on batterySweep { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

      Shape {
        anchors.fill: parent
        ShapePath {
          strokeWidth: Style.space(2.2)
          strokeColor: root.batteryPct >= 0 && root.batteryPct <= 15
            ? "#ff453a" : (root.batteryPct >= 0 && root.batteryPct <= 30
              ? "#ff9f0a" : "#30d158")
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: batteryBubble.width / 2
          startY: Style.space(4)
          PathAngleArc {
            centerX: batteryBubble.width / 2
            centerY: batteryBubble.height / 2
            radiusX: Math.max(0, batteryBubble.width / 2 - Style.space(4))
            radiusY: Math.max(0, batteryBubble.height / 2 - Style.space(4))
            startAngle: -90
            sweepAngle: batteryBubble.batterySweep
          }
        }
      }

      MouseArea {
        anchors.fill: parent
        z: 1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open()
      }

      Text {
        z: 2
        anchors.centerIn: parent
        text: root.batteryPct >= 0 ? String(root.batteryPct) : "–"
        color: root.capsuleInk
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.space(13)
        font.weight: Font.DemiBold
      }
    }
  }
}
