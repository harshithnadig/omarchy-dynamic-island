#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output=$(bash "$ROOT_DIR/island-backend.sh" get)

jq -e '
  (.media.playing | type == "boolean") and
  (.battery.available | type == "boolean") and
  (.battery.pct == null or (.battery.pct | type == "number")) and
  (.agents.antigravity.available | type == "boolean") and
  (.agents.claude_code.available | type == "boolean")
' >/dev/null <<<"$output"

echo "Dynamic Island backend smoke test passed"
