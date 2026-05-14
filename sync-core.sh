#!/bin/bash
# 将 packages/core 的共享文件同步到各子项目
# 用法：bash sync-core.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CORE="$ROOT/packages/core"

echo "▶ 同步 packages/core → langua-plugin …"
cp "$CORE/data/pinyin-data.js"   "$ROOT/langua-plugin/pinyin-data.js"
cp "$CORE/data/pinyin-ext.json"  "$ROOT/langua-plugin/pinyin-ext.json"
cp "$CORE/data/units-data.js"    "$ROOT/langua-plugin/units-data.js"
cp "$CORE/logic/segmenter.js"    "$ROOT/langua-plugin/segmenter.js"
echo "✅ langua-plugin 同步完成"

echo "▶ 同步 packages/core → langua-darwin/Sources/Langua/Resources …"
DARWIN_RES="$ROOT/langua-darwin/Sources/Langua/Resources"
cp "$CORE/data/pinyin-data.js"   "$DARWIN_RES/pinyin-data.js"
cp "$CORE/data/pinyin-ext.json"  "$DARWIN_RES/pinyin-ext.json"
cp "$CORE/data/units-data.js"    "$DARWIN_RES/units-data.js"
cp "$CORE/logic/segmenter.js"    "$DARWIN_RES/segmenter.js"
echo "✅ langua-darwin 同步完成"

echo ""
echo "完成。如需重新安装 macOS 应用，运行："
echo "  cd langua-darwin && bash build-dmg.sh --install"
