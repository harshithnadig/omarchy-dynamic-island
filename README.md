# 🏝️ Dynamic Island Pro for Omarchy

## Marketplace installation and review notes

This section describes the current implementation and takes precedence over broader feature claims below.

### Requirements and dependencies

Requires Omarchy Quattro's plugin-capable shell, Qt 6 / QtQuick / QtQuick.Controls / QtQuick.Layouts, Quickshell and Omarchy qs.Commons / qs.Ui modules. This is not a standalone QML application.

Bash, jq, playerctl, GNU coreutils and an MPRIS-compatible media player. Battery data is read from available Linux `/sys/class/power_supply/BAT*` devices. Local album art is displayed from `file://` URLs; remote art URLs are not fetched.

### Install

Review the unsandboxed plugin source, then run in an Omarchy Quattro session:

    omarchy plugin add https://github.com/harshithnadig/omarchy-dynamic-island.git --enable

Use the Omarchy bar editor to place the widget if necessary. Installation fetches upstream HEAD, not a pinned marketplace-reviewed snapshot.

### Remove

    omarchy plugin remove harshith.dynamic-island

### Permissions and persistent state

Reads media metadata and battery state. Media buttons invoke playerctl on explicit clicks. Album-art URLs, when supplied by a media player, remain optional metadata. The agent tile only reports whether `agy` or `claude` is discoverable; it does not execute or modify agent configuration.

### Current limitations

Waveform animation is decorative, not measured audio levels. The agent tile
reports executable availability, not session health or permission state. When
no supported battery is present, the panel shows unavailable rather than a
synthetic percentage.

Repository structure and documentation were reviewed for resubmission. This is not a fresh end-to-end runtime test or security audit.

### License

MIT; see LICENSE. External applications, models and dependencies retain their own licenses.

---

**Dynamic Island Pro** brings a macOS-style Liquid Glass morphing Dynamic Island with dancing audio equalizer waveforms, live media controls, and AI agent status cards directly into **Omarchy** and **Hyprland**.

---

## ✨ Features

- 🏝️ **Liquid Glass Morphing Capsule:** Physics-based spring animations that expand and contract dynamically.
- 📊 **Animated Audio Indicator:** 4-bar animation signals active playback in the capsule.
- 💿 **Album Art & Media Controls:** 1-click popout with local album art previews, a rotating vinyl fallback, play/pause, and skip buttons. Player commands have a one-second timeout so a stalled media service cannot block the bar indefinitely.
- 🤖 **AI Agent Status Bridge:** Integrated status for Google Antigravity and Claude Code sessions.
- 🔋 **Live Battery Telemetry:** Charging vitals and percentage.

---

## 🚀 Installation

Enable via Omarchy Plugin Manager:
```bash
omarchy plugin enable harshith.dynamic-island
```

The expanded media panel includes a live playback timeline with elapsed and total time. Drag it to seek in the active MPRIS player; players that do not expose duration or seeking leave the timeline disabled.
