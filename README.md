# Langua（懒瓜）

> 悬停即见拼音，轻松阅读中文
>
> *Hover over Chinese text to instantly see pinyin.*

[English](#english) | 中文

---

## 中文介绍

Langua 是一款为中文阅读提供实时拼音标注的工具，支持 **Chrome 浏览器扩展** 和 **macOS 原生应用** 两种形式。无论是正在学习中文的学习者，还是需要查看生僻字读音的母语者，只需将鼠标悬停在汉字上，拼音即刻显示。

### 功能特色

**悬停气泡（Hover Pinyin）**
将鼠标悬停在任意中文字符上，立刻弹出包含拼音的小气泡，无需打断阅读节奏。

**划词拼音（Selection Pinyin）**
鼠标拖选一段中文文字后，在选区上方弹出气泡，逐字对齐显示拼音，非汉字部分（字母、括号等）原样展示，方便对照阅读混合内容。浏览器和 macOS 应用均支持此功能，macOS 端还可识别微信等屏蔽辅助功能的应用。

**全文标注模式（Full-Text Pinyin）**
一键切换为全文模式，通过 HTML `<ruby>` 元素在每个汉字正上方显示拼音，适合深度阅读学习。滚动时按需加载，不影响页面性能。

**单位与缩写悬停提示**
悬停在医学、科学缩写（如 MCV、MCH、MCHC、HbA1c）或常见单位（如 mmHg、μmol/L）上，气泡显示对应的中文全称，无需离开页面查询。内置覆盖检验科、心内科、呼吸科等专科的缩写词典。

**上下文感知多音字消歧**
基于词语分割算法，根据上下文自动选择正确读音，准确处理常见多音字（如"行"、"重"、"长"等）。

**注音阈值配置**
在弹出菜单或浮动面板中通过滑条调节"注音阈值"（默认 6 字），全文模式下字符数低于阈值的短文本（如版权声明、按钮文字）不显示拼音标注，减少视觉干扰。

**按页面独立配置**
可为特定网站单独设置开关，全局设置与页面设置互不干扰。

**浮动控制面板**
页面内浮动按钮，无需打开扩展弹窗即可快速切换设置，按钮位置支持拖动并自动记忆。

### 平台支持

| 平台 | 说明 |
|------|------|
| Chrome / Chromium 浏览器扩展 | 在任意网页上标注拼音 |
| macOS 原生应用 | 通过辅助功能 API 在系统全局范围内悬停及划词显示拼音 |

### 安装

#### Chrome 浏览器扩展

1. 克隆本仓库：
   ```bash
   git clone https://github.com/ziyouai/langua.git
   ```

2. 打开 Chrome，进入 `chrome://extensions/`，开启右上角 **开发者模式**。

3. 点击 **加载已解压的扩展程序**，选择仓库中的 `langua-plugin` 目录。

4. 扩展图标出现在工具栏后即安装成功。

#### macOS 原生应用

> 需要 macOS 13+，并授予辅助功能权限。

1. 初始化资源文件（仅需执行一次，将共享 JS 文件复制到应用资源目录）：
   ```bash
   bash langua-darwin/setup.sh
   ```

2. 构建并安装应用：
   ```bash
   cd langua-darwin
   bash build-dmg.sh --install
   ```

3. 安装完成后，前往 **系统设置 → 隐私与安全性 → 辅助功能**，将 Langua 加入允许列表。

> **可选**：运行 `bash langua-darwin/setup-cert.sh` 生成本地自签名证书，之后每次更新应用无需重新授权辅助功能权限。

### 使用方法

#### 浏览器扩展

- **悬停拼音**：默认开启，将鼠标移到任意汉字上即可看到拼音气泡。
- **划词拼音**：鼠标拖选中文文字后松开，选区上方显示逐字对齐的拼音气泡；点击空白处或重新选择时气泡消失。
- **缩写提示**：将鼠标悬停在带虚线下划线的缩写或单位上，气泡显示中文释义。
- **全文拼音**：点击扩展图标，在弹出菜单中开启「全文拼音」，页面所有汉字将显示拼音标注，滚动时按需加载以保证性能。
- **注音阈值**：通过弹出菜单或浮动面板底部的滑条调节，实时生效，无需刷新页面。
- **作用范围**：弹出菜单顶部可切换「全局」或「当前页面」，按需独立配置。
- **浮动面板**：页面内有悬浮按钮（右侧边缘），可直接在当前页面快速切换设置，支持拖动。

#### macOS 应用

- 启动后应用驻留在菜单栏。
- 将鼠标悬停在屏幕任意位置的中文文字上，气泡即弹出拼音（浏览器页面由扩展处理，不重复标注）。
- 拖选一段中文文字后，气泡显示选中内容的拼音标注，兼容微信、备忘录等各类应用。
- 通过菜单栏图标可开关悬停拼音与划词拼音功能。

### 项目结构

```
langua/
├── langua-plugin/          # Chrome 扩展
│   ├── manifest.json       # Manifest V3 配置
│   ├── content.js          # 核心内容脚本（悬停、划词、全文模式）
│   ├── background.js       # 图标渲染
│   ├── popup.html/js       # 扩展弹窗 UI
│   ├── segmenter.js        # 词语分割（多音字消歧）
│   ├── pinyin-data.js      # 常用字拼音字典（~6500 字）
│   ├── units-data.js       # 单位与医学缩写词典
│   └── pinyin-ext.json     # 完整 CJK 字典（~20900 字）
├── langua-darwin/          # macOS 原生应用（Swift）
│   ├── Package.swift
│   ├── setup.sh            # 初始化资源脚本
│   ├── setup-cert.sh       # 本地自签名证书（可选，避免重复授权）
│   ├── Sources/Langua/
│   │   ├── AppDelegate.swift
│   │   ├── MouseTracker.swift      # 基于 AX API 的鼠标追踪
│   │   ├── SelectionTracker.swift  # 划词检测（AX + 剪贴板兜底）
│   │   ├── TextExtractor.swift     # AX 树遍历与文字提取
│   │   ├── BubbleWindowController.swift  # 气泡窗口管理
│   │   ├── BubbleView.swift        # 气泡 SwiftUI 视图
│   │   ├── PinyinEngine.swift      # JavaScriptCore 封装
│   │   └── AppState.swift          # 全局状态管理
│   └── build-dmg.sh
└── packages/core/          # 跨平台共享核心
    ├── data/               # 拼音字典、单位数据
    └── logic/              # 分词算法
```

核心语言数据与分词逻辑通过 `sync-core.sh` 同步到浏览器扩展和 macOS 应用，确保两端行为一致。

### 技术栈

**浏览器扩展**
- Manifest V3，Vanilla JavaScript
- Shadow DOM 穿透（处理 Bilibili 等使用 shadow root 的站点）
- scroll 事件 + requestIdleCallback（全文模式分帧懒加载）
- MutationObserver（动态内容感知，兼容微信文章、单页应用）

**macOS 应用**
- Swift 5.9+，Swift Package Manager
- AppKit + SwiftUI（菜单栏 UI）
- JavaScriptCore（复用浏览器端拼音逻辑，保证两端一致）
- ApplicationServices Accessibility API（跨应用文字提取与划词检测）

---

## English

Langua is a real-time pinyin annotation tool for reading Chinese text. It comes as a **Chrome browser extension** and a **macOS native app**. Hover over any Chinese character and its pinyin appears instantly — no interruption to your reading flow.

### Features

**Hover Pinyin Bubble**
Hover over any Chinese character to see a floating bubble with its pinyin pronunciation.

**Selection Pinyin**
Drag to select a passage of Chinese text and release — a bubble appears above the selection showing pinyin aligned character by character. Non-Chinese characters (letters, brackets, etc.) are displayed as-is. Works in both the browser extension and the macOS app, including apps like WeChat that block the Accessibility API.

**Full-Text Annotation Mode**
Toggle full-text mode to display pinyin above every character on the page using HTML `<ruby>` elements, ideal for study and immersive reading. Annotations are loaded lazily as you scroll to keep performance smooth.

**Unit & Abbreviation Tooltips**
Hover over medical or scientific abbreviations (e.g. MCV, MCH, MCHC, HbA1c) or units (e.g. mmHg, μmol/L) to see their full Chinese name in a tooltip. A built-in dictionary covers common abbreviations across laboratory, cardiology, respiratory, and other specialties.

**Context-Aware Polyphonic Disambiguation**
A word-segmentation algorithm determines the correct pronunciation for polyphonic characters (多音字) based on surrounding context.

**Pinyin Threshold**
A slider in the popup or floating panel controls the minimum CJK character count (default: 6) for full-text annotation. Short snippets below the threshold — such as button labels or copyright notices — are suppressed to reduce visual noise. Changes apply instantly without a page refresh.

**Per-Page Settings**
Configure settings independently for individual websites; page-level overrides coexist with global defaults without conflict.

**Floating Control Panel**
A draggable floating button lets you toggle settings directly on the page without opening the extension popup. Its position is remembered across sessions.

### Platform Support

| Platform | Description |
|----------|-------------|
| Chrome / Chromium Extension | Annotates pinyin on any web page |
| macOS Native App | Shows pinyin system-wide via the Accessibility API, with hover and selection modes |

### Installation

#### Chrome Extension

1. Clone the repository:
   ```bash
   git clone https://github.com/ziyouai/langua.git
   ```

2. Open Chrome and navigate to `chrome://extensions/`. Enable **Developer mode** in the top-right corner.

3. Click **Load unpacked** and select the `langua-plugin` directory.

4. The extension icon will appear in your toolbar.

#### macOS App

> Requires macOS 13+ and Accessibility permission.

1. Initialize resources (one-time setup — copies shared JS files into the app bundle):
   ```bash
   bash langua-darwin/setup.sh
   ```

2. Build and install the app:
   ```bash
   cd langua-darwin
   bash build-dmg.sh --install
   ```

3. After installation, go to **System Settings → Privacy & Security → Accessibility** and add Langua to the allowed list.

> **Optional**: Run `bash langua-darwin/setup-cert.sh` once to create a local self-signed certificate. This ensures the app's code signature stays stable across updates, so you won't need to re-grant Accessibility permission after each reinstall.

### Usage

#### Browser Extension

- **Hover Pinyin**: Enabled by default. Move your cursor over any Chinese character to see the pinyin bubble.
- **Selection Pinyin**: Drag to select Chinese text and release — a bubble above the selection shows character-by-character pinyin. Click elsewhere or start a new selection to dismiss it.
- **Abbreviation Tooltips**: Hover over underlined abbreviations or units to see the Chinese full name.
- **Full-Text Pinyin**: Click the extension icon and enable "Full-Text Pinyin". All Chinese characters on the page will show pinyin annotations, loaded lazily as you scroll.
- **Pinyin Threshold**: Adjust the slider in the popup or floating panel to control which short texts receive annotations. Takes effect immediately.
- **Scope**: Switch between "Global" and "This Page" at the top of the popup to apply settings independently.
- **Floating Panel**: Use the in-page floating button (right edge of the screen) to toggle settings without opening the popup. Draggable and position-persistent.

#### macOS App

- The app runs in the menu bar after launch.
- Hover over Chinese text anywhere on screen to see a pinyin bubble (browser pages are handled by the extension instead).
- Drag to select Chinese text in any app — including WeChat — to see a pinyin bubble above the selection.
- Toggle hover pinyin and selection pinyin independently via the menu bar icon.

### Tech Stack

**Browser Extension**
- Manifest V3, Vanilla JavaScript
- Shadow DOM traversal (for sites like Bilibili that use shadow roots)
- scroll event + requestIdleCallback for frame-budgeted lazy-loading in full-text mode
- MutationObserver for dynamic content awareness (WeChat articles, SPAs)

**macOS App**
- Swift 5.9+, Swift Package Manager
- AppKit + SwiftUI for menu bar UI
- JavaScriptCore to reuse the browser-side pinyin logic for consistent results across platforms
- ApplicationServices Accessibility API for cross-app text extraction and selection detection

---

## License

MIT
