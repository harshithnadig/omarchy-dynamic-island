#!/usr/bin/env bash
set -euo pipefail
# Dynamic Island Pro Backend: Telemetry, Media, Hardware, Audio, Display, Agents & Shelf

playerctl_call() {
  command -v playerctl >/dev/null 2>&1 || return 127
  timeout 1s playerctl "$@"
}

get_volume_info() {
  local vol_line pct=50 muted=false
  vol_line=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.50")
  if [[ "$vol_line" =~ ([0-9]+(\.[0-9]+)?) ]]; then
    pct=$(awk -v v="${BASH_REMATCH[1]}" 'BEGIN { printf "%d", (v * 100) + 0.5 }')
  fi
  if [[ "$vol_line" == *"[MUTED]"* ]]; then
    muted=true
  fi
  echo "$pct $muted"
}

get_brightness_info() {
  local cur max pct=50
  if command -v brightnessctl >/dev/null 2>&1; then
    cur=$(brightnessctl get 2>/dev/null || echo 50)
    max=$(brightnessctl max 2>/dev/null || echo 100)
    if (( max > 0 )); then
      pct=$(( (cur * 100) / max ))
    fi
  fi
  echo "$pct"
}

get_clipboard_info() {
  local clip_type="empty"
  local clip_text=""
  local clip_img=""

  if command -v wl-paste >/dev/null 2>&1; then
    local types
    types=$(wl-paste --list-types 2>/dev/null || true)
    if [[ -n "$types" ]]; then
      if echo "$types" | grep -q '^image/'; then
        clip_type="image"
        clip_img="/tmp/dynamic-island-pro-clip.png"
        wl-paste > "$clip_img" 2>/dev/null || clip_type="empty"
      elif echo "$types" | grep -q '^text/'; then
        clip_type="text"
        clip_text=$(wl-paste -n 2>/dev/null | head -c 256 || true)
      fi
    fi
  fi

  jq -n \
    --arg type "$clip_type" \
    --arg text "$clip_text" \
    --arg img "$clip_img" \
    '{ type: $type, text: $text, image_path: $img }'
}

get_hardware_info() {
  local cpu_pct ram_used=0 ram_total=0 ram_pct=0 swap_used=0 swap_total=0 swap_pct=0
  local gpu_name="None" gpu_vram_used=0 gpu_vram_total=0 gpu_temp=0

  cpu_pct=$(top -bn1 | grep '%Cpu' | awk '{printf "%.0f", $2}' 2>/dev/null || echo 0)

  if command -v free >/dev/null 2>&1; then
    read -r ram_used ram_total ram_pct < <(free -m 2>/dev/null | awk '/Mem:/ {printf "%d %d %.0f\n", $3, $2, ($2>0?($3/$2)*100:0)}')
    read -r swap_used swap_total swap_pct < <(free -m 2>/dev/null | awk '/Swap:/ {printf "%d %d %.0f\n", $3, $2, ($2>0?($3/$2)*100:0)}')
  fi

  if command -v nvidia-smi >/dev/null 2>&1; then
    local gpu_raw
    gpu_raw=$(nvidia-smi --query-gpu=name,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo "None,0,0,0")
    IFS=',' read -r g_name g_used g_total g_temp <<< "$gpu_raw"
    gpu_name=$(echo "${g_name:-None}" | xargs)
    gpu_vram_used=$(echo "${g_used:-0}" | xargs)
    gpu_vram_total=$(echo "${g_total:-0}" | xargs)
    gpu_temp=$(echo "${g_temp:-0}" | xargs)
  fi

  jq -n \
    --argjson cpu "$cpu_pct" \
    --argjson ram_used "$ram_used" \
    --argjson ram_total "$ram_total" \
    --argjson ram_pct "$ram_pct" \
    --argjson swap_used "$swap_used" \
    --argjson swap_total "$swap_total" \
    --argjson swap_pct "$swap_pct" \
    --arg gpu_name "$gpu_name" \
    --argjson gpu_used "$gpu_vram_used" \
    --argjson gpu_total "$gpu_vram_total" \
    --argjson gpu_temp "$gpu_temp" \
    '{
      cpu: { pct: $cpu },
      ram: { used_mb: $ram_used, total_mb: $ram_total, pct: $ram_pct },
      swap: { used_mb: $swap_used, total_mb: $swap_total, pct: $swap_pct },
      gpu: { name: $gpu_name, used_mb: $gpu_used, total_mb: $gpu_total, temp_c: $gpu_temp }
    }'
}

get_recent_screenshots() {
  local dir="$HOME/Pictures/Screenshots"
  if [[ ! -d "$dir" ]]; then
    echo "[]"
    return
  fi
  python3 -c '
import glob, os, json
dir = os.path.expanduser("~/Pictures/Screenshots")
shots = sorted(glob.glob(os.path.join(dir, "*.png")), key=os.path.getmtime, reverse=True)[:4]
result = [{"path": s, "name": os.path.basename(s)} for s in shots]
print(json.dumps(result))
' 2>/dev/null || echo "[]"
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

  # Audio & Display Telemetry
  read -r vol_pct vol_muted < <(get_volume_info)
  disp_brightness=$(get_brightness_info)

  # System Toggles (Night light & Idle)
  local night_enabled=false idle_enabled=false
  if command -v omarchy >/dev/null 2>&1; then
    local night_json idle_json
    night_json=$(omarchy toggle nightlight --status 2>/dev/null || echo '{"enabled":false}')
    idle_json=$(omarchy toggle idle status 2>/dev/null || echo '{"enabled":false}')
    night_enabled=$(jq -r '.enabled // false' <<<"$night_json")
    idle_enabled=$(jq -r '.enabled // false' <<<"$idle_json")
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
  local local_models_list="[]"

  if [[ "$include_media" == "true" ]]; then
    command -v agy >/dev/null 2>&1 && antigravity_available=true
    if pgrep -f "antigravity|agy" >/dev/null 2>&1; then antigravity_active=true; fi

    command -v claude >/dev/null 2>&1 && claude_available=true
    if pgrep -x "claude" >/dev/null 2>&1; then claude_active=true; fi

    command -v codex >/dev/null 2>&1 && codex_available=true
    if pgrep -f "codex" >/dev/null 2>&1; then codex_active=true; fi

    # Local model router / llama-swap detection & model list
    if systemctl --user is-active dsh-local-model-router >/dev/null 2>&1 || pgrep -f "llama-swap|llama.cpp" >/dev/null 2>&1; then
      local_models_available=true
      local_models_active=true
      local_models_list=$(curl -s --max-time 1 http://127.0.0.1:18080/v1/models 2>/dev/null | jq -c '[.data[]? | {id: .id, name: .name, status: (.status.value // "unloaded")}]' 2>/dev/null || echo "[]")
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

  # Clipboard & Hardware & Screenshots Telemetry
  local clip_json hw_json shots_json
  clip_json=$(get_clipboard_info)
  hw_json=$(get_hardware_info)
  shots_json=$(get_recent_screenshots)

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
    --argjson vol_pct "$vol_pct" \
    --argjson vol_muted "$vol_muted" \
    --argjson disp_brightness "$disp_brightness" \
    --argjson night_enabled "$night_enabled" \
    --argjson idle_enabled "$idle_enabled" \
    --argjson antigravity_available "$antigravity_available" \
    --argjson antigravity_active "$antigravity_active" \
    --argjson claude_available "$claude_available" \
    --argjson claude_active "$claude_active" \
    --argjson codex_available "$codex_available" \
    --argjson codex_active "$codex_active" \
    --argjson local_models_available "$local_models_available" \
    --argjson local_models_active "$local_models_active" \
    --argjson local_models_list "$local_models_list" \
    --argjson recording_active "$screen_recording_active" \
    --argjson clipboard "$clip_json" \
    --argjson hardware "$hw_json" \
    --argjson screenshots "$shots_json" \
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
      audio: {
        volume: $vol_pct,
        muted: $vol_muted
      },
      display: {
        brightness: $disp_brightness
      },
      system: {
        nightlight: $night_enabled,
        idle: $idle_enabled
      },
      recording: {
        active: $recording_active
      },
      hardware: $hardware,
      screenshots: $screenshots,
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
          endpoint: "http://127.0.0.1:18080",
          models: $local_models_list
        }
      },
      clipboard: $clipboard
    }'
}

cmd="${1:-get}"
case "$cmd" in
  battery)
    get_state false
    ;;
  volume)
    read -r vol_pct vol_muted < <(get_volume_info)
    jq -n --argjson vol "$vol_pct" --argjson muted "$vol_muted" '{ volume: $vol, muted: $muted }'
    ;;
  set-volume)
    val="${2:-50}"
    if [[ "$val" =~ ^[0-9]+$ ]] && command -v wpctl >/dev/null 2>&1; then
      (( val < 0 )) && val=0
      (( val > 100 )) && val=100
      float_val=$(awk -v v="$val" 'BEGIN { printf "%.2f", v / 100 }')
      wpctl set-volume @DEFAULT_AUDIO_SINK@ "$float_val" 2>/dev/null || true
    fi
    get_state false
    ;;
  toggle-mute)
    if command -v wpctl >/dev/null 2>&1; then
      wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || true
    fi
    get_state false
    ;;
  brightness)
    disp_brightness=$(get_brightness_info)
    jq -n --argjson b "$disp_brightness" '{ brightness: $b }'
    ;;
  set-brightness)
    val="${2:-50}"
    if [[ "$val" =~ ^[0-9]+$ ]] && command -v brightnessctl >/dev/null 2>&1; then
      (( val < 0 )) && val=0
      (( val > 100 )) && val=100
      brightnessctl set "${val}%" >/dev/null 2>&1 || true
    fi
    get_state false
    ;;
  toggle-nightlight)
    if command -v omarchy >/dev/null 2>&1; then
      omarchy toggle nightlight >/dev/null 2>&1 || true
    fi
    get_state false
    ;;
  toggle-idle)
    if command -v omarchy >/dev/null 2>&1; then
      omarchy toggle idle >/dev/null 2>&1 || true
    fi
    get_state false
    ;;
  optimize-memory)
    sync
    echo '{"optimized": true}'
    ;;
  stop-recording)
    killall -INT wf-recorder wl-screenrec obs 2>/dev/null || true
    echo '{"stopped": true}'
    ;;
  clipboard)
    get_clipboard_info
    ;;
  clear-clipboard)
    if command -v wl-copy >/dev/null 2>&1; then
      wl-copy --clear 2>/dev/null || true
    fi
    jq -n '{ type: "empty", text: "", image_path: "" }'
    ;;
  copy-text)
    text="${2:-}"
    if command -v wl-copy >/dev/null 2>&1; then
      printf '%s' "$text" | wl-copy 2>/dev/null || true
    fi
    jq -n --arg t "$text" '{ copied: true, text: $t }'
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
    if command -v wpctl >/dev/null 2>&1; then
      read -r cur_vol _ < <(get_volume_info)
      if [[ "$cmd" == "volume-up" ]]; then
        cur_vol=$((cur_vol + 5))
        (( cur_vol > 100 )) && cur_vol=100
      else
        cur_vol=$((cur_vol - 5))
        (( cur_vol < 0 )) && cur_vol=0
      fi
      float_val=$(awk -v v="$cur_vol" 'BEGIN { printf "%.2f", v / 100 }')
      wpctl set-volume @DEFAULT_AUDIO_SINK@ "$float_val" 2>/dev/null || true
    fi
    get_state false
    ;;
  *)
    get_state
    ;;
esac
