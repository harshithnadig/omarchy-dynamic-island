# Changelog

## 2.8.0

- **Flush Top-Bezel Notch Placement (0px Default):** Moved the island right up against the top screen bezel, eliminating the dark gap above the pill. Added an interactive position selector in Settings for `Flush Bezel (0px)`, `Snug (2px)`, and `Floating (6px)`.
- **Interactive Press & Elastic Hover Physics:** Added physical spring scale response (`pressScale: 0.95` on click, `1.02` on hover) with Apple-grade spring damping (`spring: 6.0, damping: 0.35`).
- **Live Hardware Health Capsule (`📊 Stats` Tab):** Real-time telemetry for CPU usage %, RAM Used/Total/%, Swap Used/Total/%, and NVIDIA RTX 4060 GPU VRAM & Temperature with visual progress bars and a 1-click **⚡ Optimize Memory** cache flush button.
- **AI Agent Permission Interceptor & Unix Socket:** Embedded a native Quickshell `SocketServer` listening at `$XDG_RUNTIME_DIR/dynamic-island/agents.sock` that intercepts tool `PermissionRequest` events from Claude Code, Codex, and Antigravity, displaying interactive `[Allow]` / `[Deny]` buttons right on the island.
- **Screen Recording Activity Pill:** Integrated live detection and pulsing red recording indicator with 1-click stop button when `wf-recorder`, `wl-screenrec`, or `obs` is active.
- **Recent Screenshots Gallery:** The Shelf tab now displays interactive thumbnails for the 4 most recent desktop screenshots with 1-click open.
- **Double Specular Curved Glass Edge:** Added horizontal gradient sheen along the top glass rim with liquid gradient background.

## 2.7.0

- **Real-Time PipeWire Cava Visualizer:** Integrated PipeWire audio spectrum monitoring via `cava` in stdout mode, feeding 4 live frequency bands into the compact equalizer bars.
- **Dynamic Bass-Reactive Ambient Halo:** The ambient backlight behind the island pulses organically with audio loudness and kicks on bass drops.
- **Apple-Grade Notification Peek Banners:** The resting pill morphs open into an elegant notification banner (42px) upon track changes, AC charger connect/disconnect, timer completion, and system toggles, auto-dismissing after 2.6s.
- **Physical Shake & Bounce Physics:** Added sinusoidal horizontal spring oscillation (`shakeX`) and vertical alert dip (`bounceY`) when focus sessions complete or alerts fire.
- **Quick Sliders in Expanded Card:** Added interactive draggable sliders for system volume (with mute toggle) and display brightness (0–100%).
- **AI Studio Supercharge & Local Models:** Added a live browser for `llama-swap` on `127.0.0.1:18080` listing 11 local models (Ternary Bonsai 2 27B, Gemma 4 12B, Granite 4.2 8B, Qwen 2.5 Coder, etc.) with 1-click test/chat, plus a Quick Prompt Launcher bar.
- **Shelf & Persistent Scratchpad:** Added live clipboard preview for copied text and images (with 1-click copy/clear) and an auto-saved persistent scratchpad.
- **Quick System Toggles:** Added one-click toggles for Night Light (`omarchy toggle nightlight`), Caffeine/Stay Awake (`omarchy toggle idle`), and Lock Session (`loginctl lock-session`).
- **Precision Input Masking:** Transparent layer shell tracks the exact bounding box of the morphing pill across compact, peeking, and expanded states, ensuring 100% click-through for background windows.

## 2.6.0
