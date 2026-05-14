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

**全文标注模式（Full-Text Pinyin）**
一键切换为全文模式，通过 HTML `<ruby>` 元素在每个汉字正上方显示拼音，适合深度阅读学习。

**上下文感知多音字消歧**
基于词语分割算法，根据上下文自动选择正确读音，准确处理常见多音字（如"行"、"重"、"长"等）。

**按页面独立配置**
可为特定网站单独设置开关，全局设置与页面设置互不干扰。

**浮动控制面板**
页面内浮动按钮，无需打开扩展弹窗即可快速切换设置，按钮位置支持拖动并自动记忆。

### 平台支持

| 平台 | 说明 |
|------|------|
| Chrome / Chromium 浏览器扩展 | 在任意网页上标注拼音 |
| macOS 原生应用 | 通过辅助功能 API 在系统全局范围内悬停显示拼音 |

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

> 需要 macOS 12+，并授予辅助功能权限。

1. 首次使用需生成自签名证书（仅需执行一次）：
   ```bash
   bash setup.sh
   ```

2. 构建并安装应用：
   ```bash
   cd langua-darwin
   bash build-dmg.sh --install
   ```

3. 安装完成后，前往 **系统设置 → 隐私与安全性 → 辅助功能**，将 Langua 加入允许列表。

### 使用方法

#### 浏览器扩展

- **悬停拼音**：默认开启，将鼠标移到任意汉字上即可看到拼音气泡。
- **全文拼音**：点击扩展图标，在弹出菜单中开启「全文拼音」，页面所有汉字将显示拼音标注，滚动时按需加载以保证性能。
- **作用范围**：弹出菜单顶部可切换「全局」或「当前页面」，按需独立配置。
- **浮动面板**：页面内有悬浮按钮，可直接在当前页面快速切换设置。

#### macOS 应用

- 启动后应用驻留在菜单栏。
- 将鼠标悬停在屏幕任意位置的中文文字上，气泡即弹出拼音（浏览器页面由扩展处理）。
- 选中一段中文文字后，将高亮显示并显示拼音标注。
- 通过菜单栏图标可开关功能。

### 项目结构

```
langua/
├── langua-plugin/          # Chrome 扩展
│   ├── manifest.json       # Manifest V3 配置
│   ├── content.js          # 核心内容脚本（悬停、全文模式）
│   ├── background.js       # 图标渲染
│   ├── popup.html/js       # 扩展弹窗 UI
│   ├── segmenter.js        # 词语分割
│   ├── pinyin-data.js      # 常用字拼音字典（~6500 字）
│   └── pinyin-ext.json     # 完整 CJK 字典（~20900 字）
├── langua-darwin/          # macOS 原生应用（Swift）
│   ├── Package.swift
│   ├── Sources/Langua/
│   │   ├── AppDelegate.swift
│   │   ├── MouseTracker.swift      # 基于 AX API 的鼠标追踪
│   │   ├── SelectionTracker.swift  # 文本选中高亮
│   │   ├── TextExtractor.swift     # AX 树遍历
│   │   ├── BubbleView.swift        # 气泡 UI
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
- Shadow DOM（气泡 UI 隔离）
- Intersection Observer（全文模式懒加载）
- MutationObserver（动态内容感知）

**macOS 应用**
- Swift 5.9+，Swift Package Manager
- AppKit + SwiftUI（菜单栏 UI）
- JavaScriptCore（复用浏览器端拼音逻辑）
- ApplicationServices Accessibility API（跨应用文字提取）

---

## English

Langua is a real-time pinyin annotation tool for reading Chinese text. It comes as a **Chrome browser extension** and a **macOS native app**. Hover over any Chinese character and its pinyin appears instantly — no interruption to your reading flow.

### Features

**Hover Pinyin Bubble**
Hover over any Chinese character to see a floating bubble with its pinyin pronunciation.

**Full-Text Annotation Mode**
Toggle full-text mode to display pinyin above every character on the page using HTML `<ruby>` elements, ideal for study and immersive reading.

**Context-Aware Polyphonic Disambiguation**
A word-segmentation algorithm determines the correct pronunciation for polyphonic characters (多音字) based on surrounding context.

**Per-Page Settings**
Configure settings independently for individual websites; page-level overrides coexist with global defaults without conflict.

**Floating Control Panel**
A draggable floating button lets you toggle settings directly on the page without opening the extension popup. Its position is remembered across sessions.

### Platform Support

| Platform | Description |
|----------|-------------|
| Chrome / Chromium Extension | Annotates pinyin on any web page |
| macOS Native App | Shows pinyin system-wide via the Accessibility API |

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

> Requires macOS 12+ and Accessibility permission.

1. Generate the self-signed certificate (one-time setup):
   ```bash
   bash setup.sh
   ```

2. Build and install the app:
   ```bash
   cd langua-darwin
   bash build-dmg.sh --install
   ```

3. After installation, go to **System Settings → Privacy & Security → Accessibility** and add Langua to the allowed list.

### Usage

#### Browser Extension

- **Hover Pinyin**: Enabled by default. Move your cursor over any Chinese character to see the pinyin bubble.
- **Full-Text Pinyin**: Click the extension icon and enable "Full-Text Pinyin". All Chinese characters on the page will show pinyin annotations, loaded lazily as you scroll.
- **Scope**: Switch between "Global" and "This Page" at the top of the popup to apply settings independently.
- **Floating Panel**: Use the in-page floating button to toggle settings without opening the popup.

#### macOS App

- The app runs in the menu bar after launch.
- Hover over Chinese text anywhere on screen to see a pinyin bubble (browser pages are handled by the extension instead).
- Selecting Chinese text highlights it and displays pinyin annotations.
- Toggle the app on/off via the menu bar icon.

### Tech Stack

**Browser Extension**
- Manifest V3, Vanilla JavaScript
- Shadow DOM for bubble UI isolation
- Intersection Observer for lazy-loading in full-text mode
- MutationObserver for dynamic content awareness

**macOS App**
- Swift 5.9+, Swift Package Manager
- AppKit + SwiftUI for menu bar UI
- JavaScriptCore to reuse the browser-side pinyin logic
- ApplicationServices Accessibility API for cross-app text extraction

---

## License

MIT
