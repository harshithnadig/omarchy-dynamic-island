#!/usr/bin/env bash
set -euo pipefail
# Dynamic Island Telemetry, Media & AI Agent Backend

playerctl_call() {
  command -v playerctl >/dev/null 2>&1 || return 127
  timeout 1s playerctl "$@"
}

get_state() {
  local include_media="${1:-true}"
  local playing=false
  local title=""
  local artist=""
  local art_url=""
  local status="Stopped"
  local position=0
  local duration=0

  if [[ "$include_media" == "true" ]] && command -v playerctl &>/dev/null; then
    status=$(playerctl_call status 2>/dev/null || echo "Stopped")
    if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
      [[ "$status" == "Playing" ]] && playing=true
      title=$(playerctl_call metadata title 2>/dev/null || true)
      artist=$(playerctl_call metadata artist 2>/dev/null || true)
      art_url=$(playerctl_call metadata mpris:artUrl 2>/dev/null || true)
      duration=$(playerctl_call metadata --format '{{mpris:length}}' 2>/dev/null || true)
      position=$(playerctl_call position 2>/dev/null || echo 0)
      [[ "$position" =~ ^[0-9]+([.][0-9]+)?$ ]] || position=0
      [[ "$duration" =~ ^[0-9]+$ ]] && duration=$((duration / 1000000)) || duration=0
      position=${position%%.*}
    fi
  fi

  local bat_status="Unavailable"
  local bat_pct="null"
  local battery_available=false
  local battery_total=0
  local battery_count=0
  local battery_status_file battery_dir capacity battery_state
  for battery_status_file in /sys/class/power_supply/BAT*/status; do
    [[ -f "$battery_status_file" ]] || continue
    battery_dir=${battery_status_file%/status}
    capacity=$(cat "$battery_dir/capacity" 2>/dev/null || true)
    battery_state=$(cat "$battery_status_file" 2>/dev/null || true)
    [[ "$capacity" =~ ^[0-9]+$ ]] || continue
    (( capacity > 100 )) && capacity=100
    battery_total=$((battery_total + capacity))
    battery_count=$((battery_count + 1))
    if [[ "$battery_state" == "Charging" ]]; then
      bat_status="Charging"
    elif [[ "$battery_state" == "Discharging" && "$bat_status" != "Charging" ]]; then
      bat_status="Discharging"
    elif [[ "$battery_state" == "Full" && "$bat_status" == "Unavailable" ]]; then
      bat_status="Full"
    elif [[ "$bat_status" == "Unavailable" && -n "$battery_state" ]]; then
      bat_status="$battery_state"
    fi
  done
  if (( battery_count > 0 )); then
    battery_available=true
    bat_pct=$((battery_total / battery_count))
  fi

  # AI Agents & Local Models Telemetry
  local antigravity_available=false
  local antigravity_active=false
  local claude_available=false
  local claude_active=false
  local codex_available=false
  local codex_active=false
  local local_models_available=false
  local local_models_active=false
  local screen_recording_active=false

  if [[ "$include_media" == "true" ]]; then
    command -v agy >/dev/null 2>&1 && antigravity_available=true
    if pgrep -f "antigravity|agy" >/dev/null 2>&1; then antigravity_active=true; fi

    command -v claude >/dev/null 2>&1 && claude_available=true
    if pgrep -x "claude" >/dev/null 2>&1; then claude_active=true; fi

    command -v codex >/dev/null 2>&1 && codex_available=true
    if pgrep -f "codex" >/dev/null 2>&1; then codex_active=true; fi

    # Local model router / llama-swap detection
    if systemctl --user is-active dsh-local-model-router >/dev/null 2>&1 || pgrep -f "llama-swap|llama.cpp" >/dev/null 2>&1; then
      local_models_available=true
      local_models_active=true
    elif command -v ollama >/dev/null 2>&1; then
      local_models_available=true
      if systemctl --user is-active ollama >/dev/null 2>&1 || pgrep -x "ollama" >/dev/null 2>&1; then
        local_models_active=true
      fi
    fi

    # Screen recording detection
    if pgrep -x "wf-recorder" >/dev/null 2>&1 || pgrep -x "wl-screenrec" >/dev/null 2>&1 || pgrep -x "obs" >/dev/null 2>&1; then
      screen_recording_active=true
    fi
  fi

  jq -n \
    --arg playing "$playing" \
    --arg status "$status" \
    --arg title "$title" \
    --arg artist "$artist" \
    --arg art_url "$art_url" \
    --argjson position "$position" \
    --argjson duration "$duration" \
    --arg bat_status "$bat_status" \
    --argjson bat_pct "$bat_pct" \
    --argjson battery_available "$battery_available" \
    --argjson antigravity_available "$antigravity_available" \
    --argjson antigravity_active "$antigravity_active" \
    --argjson claude_available "$claude_available" \
    --argjson claude_active "$claude_active" \
    --argjson codex_available "$codex_available" \
    --argjson codex_active "$codex_active" \
    --argjson local_models_available "$local_models_available" \
    --argjson local_models_active "$local_models_active" \
    --argjson recording_active "$screen_recording_active" \
    '{
      media: {
        playing: ($playing == "true"),
        status: $status,
        title: $title,
        artist: $artist,
        art_url: $art_url,
        position: $position,
        duration: $duration
      },
      battery: {
        available: $battery_available,
        status: $bat_status,
        pct: $bat_pct
      },
      recording: {
        active: $recording_active
      },
      agents: {
        antigravity: {
          available: $antigravity_available,
          active: $antigravity_active,
          name: "Google Antigravity"
        },
        claude_code: {
          available: $claude_available,
          active: $claude_active,
          name: "Claude Code"
        },
        codex: {
          available: $codex_available,
          active: $codex_active,
          name: "Codex CLI"
        },
        local_models: {
          available: $local_models_available,
          active: $local_models_active,
          name: "Local Models (Bonsai 2 / llama-swap)",
          endpoint: "http://127.0.0.1:18080"
        }
      }
    }'
}

cmd="${1:-get}"
case "$cmd" in
  battery)
    get_state false
    ;;
  play-pause)
    playerctl_call play-pause 2>/dev/null || true
    get_state
    ;;
  next)
    playerctl_call next 2>/dev/null || true
    get_state
    ;;
  previous)
    playerctl_call previous 2>/dev/null || true
    get_state
    ;;
  seek)
    value="${2:-}"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      playerctl_call position "$value" 2>/dev/null || true
    fi
    get_state
    ;;
  volume-up|volume-down)
    if command -v playerctl >/dev/null 2>&1; then
      volume=$(playerctl_call volume 2>/dev/null || echo 0)
      if [[ "$volume" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        if [[ "$cmd" == "volume-up" ]]; then
          volume=$(awk -v v="$volume" 'BEGIN { v += 0.05; if (v > 1) v = 1; printf "%.2f", v }')
        else
          volume=$(awk -v v="$volume" 'BEGIN { v -= 0.05; if (v < 0) v = 0; printf "%.2f", v }')
        fi
        playerctl_call volume "$volume" 2>/dev/null || true
      fi
    fi
    get_state
    ;;
  *)
    get_state
    ;;
esac
