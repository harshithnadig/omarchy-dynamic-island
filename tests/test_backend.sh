#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output=$(bash "$ROOT_DIR/island-backend.sh" get)

jq -e '
  (.media.playing | type == "boolean") and
  (.battery.available | type == "boolean") and
  (.battery.pct == null or (.battery.pct | type == "number")) and
  (.audio.volume | type == "number") and
  (.audio.muted | type == "boolean") and
  (.display.brightness | type == "number") and
  (.recording.active | type == "boolean") and
  (.agents.antigravity.available | type == "boolean") and
  (.agents.claude_code.available | type == "boolean") and
  (.agents.codex.available | type == "boolean") and
  (.agents.local_models.available | type == "boolean") and
  (.agents.local_models.models | type == "array")
' >/dev/null <<<"$output"

echo "Dynamic Island Pro backend tests passed successfully"
