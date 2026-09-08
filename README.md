# 🏝️ Dynamic Island Pro for Omarchy

## Marketplace installation and review notes

This section describes the current implementation and takes precedence over broader feature claims below.

### Requirements and dependencies

Requires Omarchy Quattro's plugin-capable shell, Qt 6 / QtQuick / QtQuick.Controls / QtQuick.Layouts, Quickshell and Omarchy qs.Commons / qs.Ui modules. This is not a standalone QML application.

Bash, jq, playerctl, GNU coreutils and an MPRIS-compatible media player. Battery data comes from Linux /sys/class/power_supply/BAT0 or BAT1.

### Install

Review the unsandboxed plugin source, then run in an Omarchy Quattro session:

    omarchy plugin add https://github.com/harshithnadig/omarchy-dynamic-island.git --enable

Use the Omarchy bar editor to place the widget if necessary. Installation fetches upstream HEAD, not a pinned marketplace-reviewed snapshot.

### Remove

    omarchy plugin remove harshith.dynamic-island

### Permissions and persistent state

Reads media metadata and battery state. Media buttons invoke playerctl on explicit clicks. Album art may load a URL supplied by the media player. Does not install or modify agent configuration.

### Current limitations

Waveform animation is decorative, not measured audio levels. The current backend supplies media and battery data, not an implemented AI permission-card bridge. Battery fallback values may appear without a supported battery.

Repository structure and documentation were reviewed for resubmission. This is not a fresh end-to-end runtime test or security audit.

### License

MIT; see LICENSE. External applications, models and dependencies retain their own licenses.

---

**Dynamic Island Pro** brings a macOS-style Liquid Glass morphing Dynamic Island with dancing audio equalizer waveforms, live media controls, and AI agent status cards directly into **Omarchy** and **Hyprland**.

---

## ✨ Features

- 🏝️ **Liquid Glass Morphing Capsule:** Physics-based spring animations that expand and contract dynamically.
- 📊 **Dancing Audio Waveform:** 4-bar real-time harmonic equalizer dancing to Spotify, YouTube, and VLC.
- 💿 **Album Art & Media Controls:** 1-click popout with rotating vinyl disc, play/pause, and skip buttons.
- 🤖 **AI Agent Status Bridge:** Integrated status for Google Antigravity and Claude Code sessions.
- 🔋 **Live Battery Telemetry:** Charging vitals and percentage.

---

## 🚀 Installation

Enable via Omarchy Plugin Manager:
```bash
omarchy plugin enable harshith.dynamic-island
```
