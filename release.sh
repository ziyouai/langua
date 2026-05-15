#!/bin/bash
# 统一发布脚本：构建 DMG + 插件 zip，上传到同一个 GitHub release
# 用法：bash release.sh [--version 1.2.0] [--notes "修复了xxx"]
# 前提：已安装 gh CLI 并已登录

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$ROOT/langua-plugin"
DARWIN_DIR="$ROOT/langua-darwin"
BUILD_DIR="$ROOT/langua-darwin/build"

# ── 参数 ───────────────────────────────────────────────────────────────────
VERSION=""
NOTES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --notes)   NOTES="$2";   shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# 从 manifest.json 读取版本号（未手动指定时）
if [ -z "$VERSION" ]; then
  VERSION=$(grep '"version"' "$PLUGIN_DIR/manifest.json" | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
fi

echo ""
echo "══════════════════════════════════════════"
echo "  langua v$VERSION  →  发布"
echo "══════════════════════════════════════════"
echo ""

# ── Step 1: 构建 macOS DMG ─────────────────────────────────────────────────
echo "▶ 构建 macOS DMG …"
bash "$DARWIN_DIR/build-dmg.sh" --version "$VERSION"
DMG_SRC="$BUILD_DIR/langua-$VERSION.dmg"
DMG_OUT="$BUILD_DIR/langua.dmg"
cp "$DMG_SRC" "$DMG_OUT"
echo "✅ DMG: $DMG_OUT"
echo ""

# ── Step 2: 打包 Chrome 插件 zip ───────────────────────────────────────────
echo "▶ 打包 Chrome 插件 zip …"
PLUGIN_ZIP="$BUILD_DIR/langua-plugin.zip"
rm -f "$PLUGIN_ZIP"
cd "$PLUGIN_DIR"
zip -r "$PLUGIN_ZIP" . \
  --exclude "*.DS_Store" \
  --exclude "__MACOSX/*" \
  --exclude "RULES.md" \
  > /dev/null
cd "$ROOT"
echo "✅ 插件 zip: $PLUGIN_ZIP"
echo ""

# ── Step 3: 创建 GitHub Release ────────────────────────────────────────────
echo "▶ 发布到 GitHub …"
TAG="v$VERSION"

# 如果 tag 已存在则删除旧的（重新发布同版本时用）
if gh release view "$TAG" --repo ziyouai/langua &>/dev/null; then
  echo "   ⚠️  tag $TAG 已存在，先删除旧 release …"
  gh release delete "$TAG" --repo ziyouai/langua --yes --cleanup-tag
fi

RELEASE_NOTES="${NOTES:-"langua $TAG"}"

gh release create "$TAG" \
  --repo ziyouai/langua \
  --title "langua $TAG" \
  --notes "$RELEASE_NOTES" \
  "$DMG_OUT#langua.dmg" \
  "$PLUGIN_ZIP#langua-plugin.zip"

echo ""
echo "✅ 发布完成：https://github.com/ziyouai/langua/releases/tag/$TAG"
echo ""
echo "直链（供官网使用）："
echo "  macOS:  https://github.com/ziyouai/langua/releases/latest/download/langua.dmg"
echo "  插件:   https://github.com/ziyouai/langua/releases/latest/download/langua-plugin.zip"
