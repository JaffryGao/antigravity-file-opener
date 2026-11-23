#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="AntigravityFileOpener"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
TEST_BIN="$BUILD_DIR/FileLinkParserTests"

mkdir -p "$BUILD_DIR"

echo "==> [1/3] 编译并运行单元测试..."
swiftc \
  -O \
  "$ROOT_DIR/Sources/FileLinkParser.swift" \
  "$ROOT_DIR/Tests/FileLinkParserTests.swift" \
  -o "$TEST_BIN"
"$TEST_BIN"

echo "==> [2/3] 编译 ${APP_NAME}.app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"

swiftc \
  -O \
  -framework AppKit \
  -framework Security \
  "$ROOT_DIR/Sources/FileLinkParser.swift" \
  "$ROOT_DIR/Sources/ContextMenuPresenter.swift" \
  "$ROOT_DIR/Sources/LocalActionServer.swift" \
  "$ROOT_DIR/Sources/AppDelegate.swift" \
  "$ROOT_DIR/Sources/main.swift" \
  -o "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>AntigravityFileOpener</string>
  <key>CFBundleIdentifier</key>
  <string>local.antigravity.fileopener</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>AntigravityFileOpener</string>
  <key>CFBundleDisplayName</key>
  <string>AntigravityFileOpener</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> [3/3] 执行本地签名与完整性校验..."
SIGN_ID="${SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Apple Development/ {print $2; exit}')}"
if [[ -n "$SIGN_ID" ]]; then
  echo "使用稳定开发证书签名: $SIGN_ID"
  codesign --force --deep --sign "$SIGN_ID" "$APP_BUNDLE"
else
  codesign --force --deep --sign - "$APP_BUNDLE"
fi
codesign --verify --deep --strict "$APP_BUNDLE"

echo "✅ 构建完成: $APP_BUNDLE"

if [[ "${1:-}" == "--install" ]]; then
  INSTALL_DIR="/Applications"
  rm -rf "$INSTALL_DIR/${APP_NAME}.app"
  cp -R "$APP_BUNDLE" "$INSTALL_DIR/${APP_NAME}.app"
  echo "✅ 已安装到: $INSTALL_DIR/${APP_NAME}.app"
fi
