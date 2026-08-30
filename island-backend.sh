#!/usr/bin/env bash
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

  local bat_status="Discharging"
  local bat_pct=100
  if [[ -f /sys/class/power_supply/BAT0/status ]]; then
    bat_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Discharging")
    bat_pct=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100)
  elif [[ -f /sys/class/power_supply/BAT1/status ]]; then
    bat_status=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo "Discharging")
    bat_pct=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 100)
  fi

  jq -n \
    --arg playing "$playing" \
    --arg status "$status" \
    --arg title "$title" \
    --arg artist "$artist" \
    --arg art_url "$art_url" \
    --arg bat_status "$bat_status" \
    --argjson bat_pct "$bat_pct" \
    '{
      media: {
        playing: ($playing == "true"),
        status: $status,
        title: $title,
        artist: $artist,
        art_url: $art_url
      },
      battery: {
        status: $bat_status,
        pct: $bat_pct
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
