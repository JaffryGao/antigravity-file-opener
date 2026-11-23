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

NODE_BIN="$(find_node || true)"
if [[ -z "$NODE_BIN" ]]; then
  echo "❌ 未找到 Node.js，请先安装 Node.js（如 brew install node）后再执行。"
  exit 1
fi

# 1. 先停掉旧服务与旧手动实例，避免重复运行
launchctl bootout "gui/${UID_NUM}/${PLIST_LABEL}" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true

# 2. 运行测试、编译并安装到 /Applications/AntigravityFileOpener.app
"$ROOT_DIR/build.sh" --install

# 3. 写入 LaunchAgent（开机静默自启，重启电脑与重启 Antigravity 后自动可用）
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_APP}/Contents/MacOS/${APP_NAME}</string>
        <string>--silent</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>5</integer>
    <key>StandardOutPath</key>
    <string>/tmp/antigravity-file-opener.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/antigravity-file-opener.err</string>
</dict>
</plist>
PLIST

# 4. 校验 plist 语法并注册启动
plutil -lint "$PLIST_PATH"
launchctl bootstrap "gui/${UID_NUM}" "$PLIST_PATH"
launchctl kickstart -k "gui/${UID_NUM}/${PLIST_LABEL}"

sleep 1
echo "==> 同步前端交互模块到 theme-patch/user/custom.js..."
"$NODE_BIN" "$ROOT_DIR/sync-custom-js.mjs" install

echo "==> 检查后台服务状态:"
launchctl print "gui/${UID_NUM}/${PLIST_LABEL}" | grep -E "state =|pid =|last exit code" || true
echo "✅ 安装并启动完成！"
