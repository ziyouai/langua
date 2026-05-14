#!/bin/bash
# langua-darwin — 打包 DMG / 一键安装
# 用法:
#   bash build-dmg.sh                        # 仅打包 DMG
#   bash build-dmg.sh --install              # 打包 + 安装到 /Applications + 重启
#   bash build-dmg.sh --version 1.1.0
#   bash build-dmg.sh --identity "Developer ID Application: ..."

set -euo pipefail

# ── Xcode 路径检测 ─────────────────────────────────────────────────────────
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

# ── 参数 ───────────────────────────────────────────────────────────────────
APP_NAME="Langua"
BUNDLE_ID="com.langua.darwin"
VERSION="1.0.0"
SIGN_IDENTITY="-"
DO_INSTALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)  VERSION="$2";       shift 2 ;;
    --identity) SIGN_IDENTITY="$2"; shift 2 ;;
    --install)  DO_INSTALL=true;    shift   ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

ROOT="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$ROOT/../packages/core"
BUILD_DIR="$ROOT/build"

# ── Step 0: 从 packages/core 同步共享文件 ──────────────────────────────────
echo "▶ 同步 packages/core → Sources/Langua/Resources …"
RESOURCES="$ROOT/Sources/Langua/Resources"
cp "$CORE_DIR/data/pinyin-data.js"        "$RESOURCES/pinyin-data.js"
cp "$CORE_DIR/data/pinyin-ext.json"       "$RESOURCES/pinyin-ext.json"
cp "$CORE_DIR/data/units-data.js"         "$RESOURCES/units-data.js"
cp "$CORE_DIR/logic/segmenter.js"         "$RESOURCES/segmenter.js"
# 图标从 core 统一管理
cp "$CORE_DIR/assets/icons/AppIcon.icns"      "$ROOT/Resources/AppIcon.icns"
cp "$CORE_DIR/assets/icons/toolbar-icon32.png" "$ROOT/Sources/Langua/Resources/toolbar-icon32.png"
echo "✅ 同步完成"
echo ""
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_OUT="$BUILD_DIR/langua-$VERSION.dmg"

echo ""
echo "══════════════════════════════════════════"
echo "  langua $VERSION  →  DMG 打包"
echo "══════════════════════════════════════════"
echo ""

# ── Step 1: 编译 Release ────────────────────────────────────────────────────
echo "▶ swift build -c release …"
cd "$ROOT"
swift build -c release 2>&1 | grep -E "^(Build|error:|warning:|note:)" || true
# 确认产物存在
BINARY=".build/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
  echo "❌ 编译失败，找不到 $BINARY"
  exit 1
fi
echo "✅ 编译完成: $BINARY"
echo ""

# ── Step 2: 构建 .app bundle 目录树 ────────────────────────────────────────
echo "▶ 组装 .app bundle …"
rm -rf "$APP_BUNDLE"
CONTENTS="$APP_BUNDLE/Contents"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# 可执行文件
cp "$BINARY" "$CONTENTS/MacOS/$APP_NAME"
chmod +x "$CONTENTS/MacOS/$APP_NAME"

# JS 资源 + 图标
for f in pinyin-data.js pinyin-ext.json segmenter.js units-data.js toolbar-icon32.png; do
  SRC="$ROOT/Sources/Langua/Resources/$f"
  if [ -f "$SRC" ]; then
    cp "$SRC" "$CONTENTS/Resources/$f"
  else
    echo "⚠️  找不到 $f，运行 setup.sh 先复制 JS 文件"
  fi
done

# App 图标（如果有的话）
ICON_SRC="$ROOT/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
  cp "$ICON_SRC" "$CONTENTS/Resources/AppIcon.icns"
fi

# ── Step 3: 写 Info.plist ──────────────────────────────────────────────────
echo "▶ 写入 Info.plist …"
cat > "$CONTENTS/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>

    <key>CFBundleName</key>
    <string>langua</string>
    <key>CFBundleDisplayName</key>
    <string>langua</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>

    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>

    <!-- 不在 Dock 显示 -->
    <key>LSUIElement</key>
    <true/>

    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>

    <!-- Accessibility 权限说明（系统弹窗显示） -->
    <key>NSAccessibilityUsageDescription</key>
    <string>langua 需要辅助功能权限以读取屏幕上的文字，用于显示拼音注音。</string>

    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
PLIST
echo "✅ Info.plist 写入完成"
echo ""

# ── Step 4: 代码签名 ───────────────────────────────────────────────────────
# 自动检测本地自签名证书（setup-cert.sh 创建），避免每次重签导致 TCC 权限失效
if [ "$SIGN_IDENTITY" = "-" ]; then
  LOCAL_CERT=$(security find-identity -v -p codesigning \
    ~/Library/Keychains/login.keychain-db 2>/dev/null \
    | grep "Langua Dev" | awk -F '"' '{print $2}' | head -1)
  if [ -n "$LOCAL_CERT" ]; then
    SIGN_IDENTITY="$LOCAL_CERT"
    echo "▶ 使用本地自签名证书: $SIGN_IDENTITY"
  else
    echo "▶ 未找到本地证书，使用 Ad-hoc 签名（辅助权限每次重装需重新授权）"
    echo "   提示：运行 bash setup-cert.sh 一次，之后权限就不会失效。"
  fi
fi

echo "▶ 代码签名（identity: ${SIGN_IDENTITY}）…"
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --deep --force --sign "-" --timestamp=none "$APP_BUNDLE"
  echo "✅ Ad-hoc 签名完成"
else
  codesign --deep --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP_BUNDLE"
  echo "✅ 签名完成"
fi
echo ""

# ── Step 5: 创建 DMG ───────────────────────────────────────────────────────
echo "▶ 创建 DMG …"
STAGING="$BUILD_DIR/.dmg-staging"
rm -rf "$STAGING" "$DMG_OUT"
mkdir -p "$STAGING"

cp -r "$APP_BUNDLE" "$STAGING/"
# "拖入 Applications" 的快捷方式
ln -s /Applications "$STAGING/Applications"

# 先创建可读写 DMG
TEMP_DMG="$BUILD_DIR/.langua-temp.dmg"
hdiutil create \
  -volname "langua" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDRW \
  -size 200m \
  "$TEMP_DMG" > /dev/null

# 挂载，设置 Finder 窗口外观（可选，但让拖拽体验更好）
MOUNT_DIR="$(hdiutil attach "$TEMP_DMG" -readwrite -nobrowse | grep "/Volumes/" | awk '{print $3}')"
if [ -n "$MOUNT_DIR" ]; then
  # 设置窗口位置和图标尺寸（AppleScript 方式）
  osascript << APPLESCRIPT > /dev/null 2>&1 || true
tell application "Finder"
  tell disk "langua"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 200, 680, 420}
    set theViewOptions to icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set position of item "Langua.app" of container window to {140, 100}
    set position of item "Applications" of container window to {340, 100}
    close
    eject
  end tell
end tell
APPLESCRIPT
  # 等待 Finder 完成
  sleep 1
  hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
fi

# 转为只读压缩 DMG
hdiutil convert "$TEMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_OUT" > /dev/null

rm -f "$TEMP_DMG"
rm -rf "$STAGING"

# ── 完成 ────────────────────────────────────────────────────────────────────
echo "✅ DMG 完成：$DMG_OUT"
echo ""

if $DO_INSTALL; then
  INSTALL_PATH="/Applications/$APP_NAME.app"
  echo "▶ 安装到 $INSTALL_PATH …"

  # 1. 退出正在运行的旧版本（通过 bundle id 精准匹配，不影响其他进程）
  if pgrep -f "$BUNDLE_ID" > /dev/null 2>&1 || \
     osascript -e "tell application \"$APP_NAME\" to quit" > /dev/null 2>&1; then
    echo "   已退出旧版 $APP_NAME"
    sleep 0.8   # 等待进程完全退出
  fi
  # 兜底：如果还在跑，强制结束
  pkill -f "MacOS/$APP_NAME" 2>/dev/null || true
  sleep 0.3

  # 2. 仅 Ad-hoc 签名时才重置 TCC（Ad-hoc 每次签名不同，系统视为新 app）
  # 使用固定证书（Langua Dev）时签名一致，无需重置，权限可以保留
  if [ "$SIGN_IDENTITY" = "-" ]; then
    tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
    echo "   ⚠️  Ad-hoc 签名：已重置辅助功能权限（需重新授权一次）"
    echo "   提示：运行 bash setup-cert.sh 创建本地证书，之后更新不再需要重新授权"
  else
    echo "   ✅ 已签名证书一致 (${SIGN_IDENTITY})，辅助功能权限保留"
  fi

  # 3. 替换 /Applications 里的旧版本
  rm -rf "$INSTALL_PATH"
  cp -r "$APP_BUNDLE" "$INSTALL_PATH"
  echo "✅ 已安装：$INSTALL_PATH"

  # 4. 重新启动
  open "$INSTALL_PATH"
  echo "✅ 已启动 langua"
else
  # 仅打包时在 Finder 里高亮 DMG
  open -R "$DMG_OUT"
fi
