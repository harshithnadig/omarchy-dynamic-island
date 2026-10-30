#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

MOCK_BIN="$TEST_ROOT/bin"
RUNTIME_DIR="$TEST_ROOT/runtime"
mkdir -m 700 "$MOCK_BIN" "$RUNTIME_DIR"

cat > "$MOCK_BIN/wl-paste" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--list-types" ]]; then
  if [[ "${MOCK_CLIPBOARD_KIND:-image}" == "text" ]]; then
    printf 'text/plain\n'
  else
    printf 'image/png\n'
  fi
elif [[ "${1:-}" == "-n" ]]; then
  printf 'private test text'
elif [[ "${MOCK_CLIPBOARD_KIND:-image}" == "large" ]]; then
  dd if=/dev/zero bs=1048576 count=21 2>/dev/null
else
  printf 'mock-image-data'
fi
MOCK
chmod 700 "$MOCK_BIN/wl-paste"

cat > "$MOCK_BIN/wl-copy" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod 700 "$MOCK_BIN/wl-copy"

run_clipboard() {
  MOCK_CLIPBOARD_KIND="$1" \
    PATH="$MOCK_BIN:$PATH" \
    XDG_RUNTIME_DIR="$RUNTIME_DIR" \
    bash "$ROOT_DIR/island-backend.sh" clipboard
}

result=$(run_clipboard image)
image_path=$(jq -r '.image_path' <<< "$result")
[[ $(jq -r '.type' <<< "$result") == image ]]
[[ "$image_path" == "$RUNTIME_DIR/dynamic-island/clipboard.png" ]]
[[ $(stat -c '%a' "$RUNTIME_DIR/dynamic-island") == 700 ]]
[[ $(stat -c '%a' "$image_path") == 600 ]]
[[ $(cat "$image_path") == mock-image-data ]]

result=$(run_clipboard text)
[[ $(jq -r '.type' <<< "$result") == text ]]
[[ ! -e "$RUNTIME_DIR/dynamic-island/clipboard.png" ]]

run_clipboard image >/dev/null
PATH="$MOCK_BIN:$PATH" XDG_RUNTIME_DIR="$RUNTIME_DIR" \
  bash "$ROOT_DIR/island-backend.sh" clear-clipboard >/dev/null
[[ ! -e "$RUNTIME_DIR/dynamic-island/clipboard.png" ]]

result=$(run_clipboard large)
[[ $(jq -r '.type' <<< "$result") == empty ]]
[[ $(jq -r '.image_path' <<< "$result") == "" ]]
[[ ! -e "$RUNTIME_DIR/dynamic-island/clipboard.png" ]]

echo "Clipboard privacy tests passed successfully"
