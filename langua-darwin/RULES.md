# langua-darwin 开发注意事项

## 🚨 每次安装只能用这一条命令，其他方式都会导致辅助功能权限失效

```bash
bash build-dmg.sh --install
```

**绝对不能手动** `cp` 二进制 + `codesign`，会破坏签名一致性，导致每次都要重新授权。

---

## ⚠️ 安装必须用脚本，不能手动复制二进制

**错误做法（每次都要重新授权辅助功能权限）：**
```bash
cp .build/release/Langua /Applications/Langua.app/Contents/MacOS/Langua
codesign --deep --force --sign - /Applications/Langua.app
```

**正确做法：**
```bash
bash build-dmg.sh --install
```

`build-dmg.sh --install` 会自动：
1. 编译 Release
2. 用"Langua Dev"自签名证书签名（签名一致 → 权限不失效）
3. 调用 `tccutil reset Accessibility com.langua.darwin` 清理旧权限记录
4. 替换 /Applications/Langua.app 并重启

## 首次配置：生成自签名证书

首次使用前运行一次，之后权限就不会因更新而失效：
```bash
bash setup-cert.sh
```

没有证书时 build-dmg.sh 会回退到 Ad-hoc 签名，每次安装都需要重新在
「系统设置 → 隐私与安全性 → 辅助功能」里授权。

## 日常开发流程

```bash
# 仅编译（快速验证）
swift build

# 编译 + 安装 + 重启
bash build-dmg.sh --install

# 仅打包 DMG（不安装）
bash build-dmg.sh
```

## 权限说明

| 权限 | 用途 | 必须 |
|------|------|------|
| 辅助功能（Accessibility）| AX API 读取文字 | ✅ 必须 |
| 屏幕录制（Screen Recording）| OCR 兜底（微信等 Electron app）| 推荐开启 |

## 不要处理浏览器

浏览器（Safari / Chrome / Arc / Firefox / Edge 等）由专门的 Chrome 扩展处理，
TextExtractor 里已按 bundle ID 排除，不要删除这个判断。
