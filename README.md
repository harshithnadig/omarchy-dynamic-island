# Dynamic Island Pro for Omarchy

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Omarchy Quattro](https://img.shields.io/badge/Omarchy-Quattro-8b5cf6.svg)](https://omarchy.org)
[![Quickshell](https://img.shields.io/badge/Quickshell-0.3.2+-38bdf8.svg)](https://quickshell.outfoxxed.me)

An Apple-style **Liquid Glass Dynamic Island** positioned at the top-center of your screen for **Omarchy** and **Hyprland**. Resting permanently as a sleek top-center pill that morphs organically in place, peeks fluidly on notifications, dances to live audio with Cava, shakes on alerts, and expands into a unified command center.

![Dynamic Island Pro Icon](assets/icon.svg)

---

## ✨ Features

### 🏝️ True In-Place Morphing & Fluid Spring Physics
- **Permanent Top-Center Resting Pill:** Sits elegantly at the top-center of your screen (34px height) without taking screen estate or blocking underlying windows.
- **Organic In-Place Spring Morphing:** Morphs smoothly between Resting Pill (34px) $\rightarrow$ Notification Peek Banner (42px) $\rightarrow$ Full Liquid Glass Card (480×480px).
- **Physical Shake & Dip Physics:** Sinusoidal damped oscillation (`shakeX`) and vertical bounce (`bounceY`) that physically shakes the island when focus sessions complete or alerts fire.
- **100% Click-Through Masking:** All desktop space outside the island is completely transparent and click-through.

### 🔔 Apple-Grade Notification Peek Banners
- **Live System Peeking:** The island springs open into an elegant notification banner for ~2.6s upon:
  - Track changes (song title, artist, art thumbnail)
  - Charger connected (`⚡ AC Power Connected`) or disconnected (`🔋 Running on Battery`)
  - Focus session completion
  - Wallpaper changes & screenshot captures
  - System toggles (Night Light, Caffeine)
- **1-Click Deep Navigation:** Clicking any peek banner morphs directly into that feature's expanded tab.

### 🎵 Real-Time Cava Audio Spectrum & MPRIS Control
- **True PipeWire Cava Visualizer:** 4-bar dancing equalizer tuned to live audio frequency spectrum via Cava, with graceful fallback animation.
- **Bass-Reactive Dynamic Ambient Glow:** Backlight halo pulses organically with audio loudness and kicks on bass drops.
- **Universal Album Artwork & Vinyl Disc:** Smooth artwork loading from local paths, `file://`, and `http(s)://`, with a rotating vinyl record fallback.
- **Interactive Seek Bar & Multi-Player Chips:** Scrubber bar with timestamps, plus quick chips to switch between Spotify, Firefox, MPV, etc.

### 🎛️ Quick Sliders & System Control
- **Interactive Audio Volume Slider:** Draggable volume slider with mute toggle and exact percentage readout.
- **Interactive Display Brightness Slider:** Draggable brightness slider (0–100%).
- **Hyprland Workspaces & Windows:** Visual workspace switcher chips and open window list with 1-click focus.
- **Quick Action Bar:**
  - ▧ **Wallpaper:** Cycle background (`omarchy theme bg next`)
  - ◐ **Theme:** Open theme switcher (`omarchy theme switcher`)
  - 📸 **Screenshot:** Wayland screenshot capture (`omarchy screenshot`)
  - 🌙 **Night Light:** Toggle color temperature (`omarchy toggle nightlight`)
  - ☕ **Caffeine:** Stay awake toggle (`omarchy toggle idle`)
  - 🔒 **Lock:** Instant lock session (`loginctl lock-session`)

### 🤖 AI Agents & Local Models Hub (Bonsai 2 / llama-swap)
- **Session Telemetry:** Live detection of running turns for **Google Antigravity**, **Claude Code**, and **Codex CLI**.
- **Local Models Browser:** Connects to `llama-swap` on `127.0.0.1:18080`, enumerating 11 available models (including **Ternary Bonsai 2 27B**, **Gemma 4 12B**, **Granite 4.2 8B**, **Qwen 2.5 Coder**) with 1-click terminal chat/test.
- **Quick Prompt Launcher:** Type a prompt directly into the island and launch with your favorite coding agent.

### 📋 Shelf & Persistent Scratchpad
- **Live Clipboard Preview:** Shows copied text snippet or full image thumbnail with 1-click "Copy Again" and "Clear" buttons.
- **Auto-Saved Scratchpad:** Persistent multi-line notepad for draft prompts, code snippets, or thoughts that survives shell reboots.

### ⏱️ Focus Studio & Splitting Satellite
- **Focus & Deep Work Presets:** 1-click timers (25m Focus, 50m Deep, 5m Break, 15m Long) with custom session names.
- **Audible Chimes:** Completion chime via `canberra-gtk-play`.
- **Splitting Satellite Bubble:** Shows timer or stopwatch alongside music without cluttering the main pill.

---

## 🎮 Gestures & Shortcuts

| Action | Gesture |
|---|---|
| **Open Card** | Left-Click on resting pill or peek banner |
| **Play / Pause** | Middle-Click on capsule |
| **Cycle Players** | Right-Click on capsule |
| **Volume HUD** | Mouse Wheel Up / Down over capsule |
| **Dismiss Card** | Press `Escape` or click outside the card |

---

## 📦 Installation & Verification

To install or update in Omarchy:

```sh
omarchy plugin add https://github.com/harshithnadig/omarchy-dynamic-island.git --enable
```

Validate the plugin:

```sh
omarchy plugin validate ~/.config/omarchy/plugins/harshith.dynamic-island
```

Run test suite:

```sh
~/.config/omarchy/plugins/harshith.dynamic-island/tests/test_backend.sh
```

---

## 📄 License

MIT License. Copyright (c) Harshith Nadig. See [LICENSE](LICENSE) for details.
