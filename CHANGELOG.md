# Changelog

## 2.6.0

- **Liquid Glass Top-Center Island:** Overhauled presentation into a true physical top-center Dynamic Island with smooth spring animations and specular highlight edges.
- **Smart Active Reveal & Pin Mode:** The island dynamically stays visible in compact mode when media, timers, or recordings are active, and can be pinned permanently via a quick toggle.
- **Dancing 4-Bar Equalizer:** Replaced static dots with real-time 4-bar dynamic audio equalizer waveforms that dance during playback and settle on pause.
- **Universal Album Artwork & Vinyl Disc:** Added universal URL resolution supporting `file://`, local absolute paths, and remote `http(s)://` art URLs with a rotating vinyl record fallback animation.
- **Inline Volume HUD:** Scrolling over the island pill dynamically adjusts MPRIS volume with a physical gauge and percentage readout overlay.
- **Multi-Player Support:** Added right-click player cycling directly on the island pill and a responsive chip carousel in the Music panel.
- **AI Agents & Local Models Hub:** Integrated status cards and 1-click launchers for Google Antigravity, Claude Code, Codex CLI, and Local Models (Bonsai 2 / llama-swap router).
- **Audio Chimes for Focus Studio:** Added completion sound chimes via `canberra-gtk-play` and desktop notifications for Focus and Deep Work sessions.
- **Quick System Actions:** Added instant screenshot tool integration (`omarchy-capture-screenshot`), wallpaper cycler, theme switcher, and terminal summoner.
- **High-DPI & Scale Safety:** Raised layer shell boundary height and hit zones to prevent clipping across fractional display scales.
- **Branding & Assets:** Added custom SVG vector icon (`assets/icon.svg`) and validated against Omarchy plugin schema version 1.

## 2.5.0

- Moved the island to a top-center hover reveal with a delayed, springy entrance and an inline expanded capsule.
- Added a click-through service layer with input limited to the reveal sensor and island.
- Removed the bar widget entry so the island has no launcher icon in the bar.

## 2.4.0

- Replaced the static idle label with a live clock.
- Added a two-line media title and artist display.
- Added spring resizing and fade transitions for activity capsules.
- Added Omarchy theme switcher and next-background actions to the Desk view.

## 2.3.0

- Added an Omarchy-themed overlay presentation above fullscreen windows.
- Kept the existing bottom-bar island for normal windowed use.
- Limited overlay input to the island surface so the rest of the screen passes through.
- Added hover-revealed play/pause and next-track controls.

## 2.2.0

- Added a Hyprland Desk view with workspace occupancy and active-window context.
- Added one-click workspace switching and click-to-focus window rows.
- Matched island capsule surfaces and outlines to Omarchy's active theme.

## 2.1.0

- Added Focus Studio with named focus and break presets.
- Added a custom session label and a persistent completed-focus count.
- Added session-aware completion notifications.
- Kept timer state from version 2.0.0 readable during upgrade.

## 2.0.0

- Replaced media shell polling with Quickshell's native MPRIS service.
- Added automatic player following and a manual multi-player picker.
- Added player capability checks for transport, seek, and volume actions.
- Added an independent timer bubble and a second stopwatch bubble.
- Persisted timer and stopwatch state across Quickshell reloads.
- Added timer completion notification and one-minute adjustment from the bar.
- Reworked the panel into Home, Music, and Timer views.
- Removed the decorative audio waveform and executable-presence agent card.
