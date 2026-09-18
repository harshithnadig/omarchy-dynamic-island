#!/usr/bin/env bash
set -euo pipefail
# Dynamic Island Telemetry & Media Backend

get_state() {
  local playing=false
  local title=""
  local artist=""
  local art_url=""
  local status="Stopped"

  if command -v playerctl &>/dev/null; then
    status=$(playerctl status 2>/dev/null || echo "Stopped")
    if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
      playing=true
      title=$(playerctl metadata --format '{{title}}' 2>/dev/null || echo "")
      artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null || echo "")
      art_url=$(playerctl metadata --format '{{mpris:artUrl}}' 2>/dev/null || echo "")
    fi
  fi

  local bat_status="Unavailable"
  local bat_pct="null"
  local battery_available=false
  local battery_total=0
  local battery_count=0
  local battery_status_file battery_dir capacity status
  for battery_status_file in /sys/class/power_supply/BAT*/status; do
    [[ -f "$battery_status_file" ]] || continue
    battery_dir=${battery_status_file%/status}
    capacity=$(cat "$battery_dir/capacity" 2>/dev/null || true)
    status=$(cat "$battery_status_file" 2>/dev/null || true)
    [[ "$capacity" =~ ^[0-9]+$ ]] || continue
    (( capacity > 100 )) && capacity=100
    battery_total=$((battery_total + capacity))
    battery_count=$((battery_count + 1))
    if [[ "$status" == "Charging" ]]; then
      bat_status="Charging"
    elif [[ "$status" == "Discharging" && "$bat_status" != "Charging" ]]; then
      bat_status="Discharging"
    elif [[ "$status" == "Full" && "$bat_status" == "Unavailable" ]]; then
      bat_status="Full"
    elif [[ "$bat_status" == "Unavailable" && -n "$status" ]]; then
      bat_status="$status"
    fi
  done
  if (( battery_count > 0 )); then
    battery_available=true
    bat_pct=$((battery_total / battery_count))
  fi

  local antigravity_available=false
  local claude_available=false
  command -v agy >/dev/null 2>&1 && antigravity_available=true
  command -v claude >/dev/null 2>&1 && claude_available=true

  jq -n \
    --arg playing "$playing" \
    --arg status "$status" \
    --arg title "$title" \
    --arg artist "$artist" \
    --arg art_url "$art_url" \
    --arg bat_status "$bat_status" \
    --argjson bat_pct "$bat_pct" \
    --argjson battery_available "$battery_available" \
    --argjson antigravity_available "$antigravity_available" \
    --argjson claude_available "$claude_available" \
    '{
      media: {
        playing: ($playing == "true"),
        status: $status,
        title: $title,
        artist: $artist,
        art_url: $art_url
      },
      battery: {
        available: $battery_available,
        status: $bat_status,
        pct: $bat_pct
      },
      agents: {
        antigravity: {available: $antigravity_available},
        claude_code: {available: $claude_available}
      }
    }'
}

cmd="${1:-get}"
case "$cmd" in
  play-pause)
    playerctl play-pause 2>/dev/null || true
    get_state
    ;;
  next)
    playerctl next 2>/dev/null || true
    get_state
    ;;
  previous)
    playerctl previous 2>/dev/null || true
    get_state
    ;;
  *)
    get_state
    ;;
esac
