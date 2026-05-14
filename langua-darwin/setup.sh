#!/bin/bash
# langua-darwin — 初始化脚本
# 把插件的拼音 JS 文件复制到 Swift 包资源目录，供 PinyinEngine 加载。

set -e

PLUGIN_DIR="$(dirname "$0")/../langua-plugin"
RESOURCES_DIR="$(dirname "$0")/Sources/Langua/Resources"

echo "📦 langua-darwin setup"
echo "插件目录: $PLUGIN_DIR"
echo "资源目录: $RESOURCES_DIR"
echo ""

# 检查插件目录
if [ ! -d "$PLUGIN_DIR" ]; then
  echo "❌ 找不到插件目录: $PLUGIN_DIR"
  echo "请确保 langua-plugin 和 langua-darwin 在同一父目录下。"
  exit 1
fi

mkdir -p "$RESOURCES_DIR"

# 复制 JS 文件
for f in pinyin-data.js segmenter.js units-data.js; do
  if [ -f "$PLUGIN_DIR/$f" ]; then
    cp "$PLUGIN_DIR/$f" "$RESOURCES_DIR/$f"
    echo "✅ 已复制 $f"
  else
    echo "⚠️  找不到 $PLUGIN_DIR/$f，跳过"
  fi
done

echo ""
echo "完成！现在可以用 Xcode 打开 Package.swift 并 Build & Run。"
echo ""
echo "首次运行需要授权辅助功能权限："
echo "  系统设置 → 隐私与安全性 → 辅助功能 → 勾选 langua"
