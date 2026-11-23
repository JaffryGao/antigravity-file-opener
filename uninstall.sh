#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AntigravityFileOpener"
INSTALL_APP="/Applications/${APP_NAME}.app"
PLIST_LABEL="com.antigravity.file-opener"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"
UID_NUM="$(id -u)"

find_node() {
  if command -v node >/dev/null 2>&1; then
    command -v node
    return 0
  fi
  for candidate in \
    /opt/homebrew/bin/node \
    /usr/local/bin/node \
    "$HOME"/.nvm/versions/node/*/bin/node(N[-1]) \
    "$HOME/.volta/bin/node"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

launchctl bootout "gui/${UID_NUM}/${PLIST_LABEL}" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
rm -f "$PLIST_PATH"
rm -rf "$INSTALL_APP"
rm -rf "$HOME/.config/antigravity-file-opener"

NODE_BIN="$(find_node || true)"
if [[ -n "$NODE_BIN" ]]; then
  "$NODE_BIN" "$ROOT_DIR/sync-custom-js.mjs" uninstall 2>/dev/null || true
fi

echo "✅ 已彻底卸载 AntigravityFileOpener 后台服务、前端扩展与配置。"
