# langua 插件 — 修改禁忌清单

每次修改 CSS 或 content.js 之前，先过一遍这个列表。
所有条目都是踩过坑、修复过的，**不要重复引入**。

---

## CSS 禁忌

### ❌ 禁止用 `!important` 覆盖布局相关属性
```css
/* 错误示例 */
body.hr-ruby-mode * { line-height: 2.6 !important; }
body.hr-ruby-mode p  { overflow: visible !important; }
```
**原因**：页面 JS 会读取 `getComputedStyle` 里的 `lineHeight`、`overflow` 等值，
`!important` 强制覆盖后，页面 JS 检测到值被改就尝试恢复，
我们的 `!important` 再次覆盖，形成循环 → **持续抖动**。

✅ 正确做法：只给插件自己创建的元素（`ruby.hr-char`、`#hr-bubble` 等）加样式，
不触碰页面原有元素的布局属性。

---

### ❌ 禁止用 `*` 作为全文模式选择器
```css
/* 错误示例 */
body.hr-ruby-mode * { line-height: 2.6 !important; }
```
**原因**：覆盖范围太广，影响导航栏、弹窗、按钮等所有元素，破坏页面布局。

---

### ❌ 禁止给通用容器标签加 `overflow: visible !important`
```css
/* 错误示例 */
body.hr-ruby-mode div,
body.hr-ruby-mode span,
body.hr-ruby-mode section,
body.hr-ruby-mode a { overflow: visible !important; }
```
**原因**：`div`/`span`/`section`/`a` 覆盖了几乎所有元素，
破坏下拉菜单、轮播、文字省略等依赖 `overflow:hidden` 的组件。

✅ 正确做法：只在 `ruby.hr-char.hr-readable` 自身设 `overflow: visible`（不加 `!important`）。

---

### ❌ 禁止给每个 ruby 字符加 `position: relative; z-index`
```css
/* 错误示例 */
body.hr-ruby-mode ruby.hr-char.hr-readable {
  position: relative;
  z-index: 1;
}
```
**原因**：页面有几百个汉字时，每个字都创建 stacking context，
浏览器持续合成图层 → **repaint 循环 → 持续抖动**。

---

### ❌ 禁止给 `.hr-rt`（拼音注音）加 `text-shadow`
```css
/* 错误示例 */
.hr-rt { text-shadow: 0 0 3px rgba(0,0,0,0.9); }
```
**原因**：改变了用户已经认可的拼音视觉风格，且在深色背景上反而更难看。

---

## JS 禁忌

### ❌ 禁止把 `'A'` 从 NAV_TAGS 中移除
```js
// 错误示例
const NAV_TAGS = new Set(['NAV','HEADER','FOOTER','ASIDE','MENU','DIALOG']);
// 漏掉了 'A'
```
**原因**：`<a>` 标签内的文字（链接、菜单项）在全文模式下不应显示注音，
只保留悬停气泡即可。`'A'` 必须保留在 NAV_TAGS 里。

---

### ❌ 禁止用 `chrome.storage.local` 存储当前页专属设置
**原因**：`chrome.storage.local` 是扩展全局共享的，
存进去的值对所有标签页都生效，无法实现"只影响当前页"。

✅ 正确做法：当前页设置写入该页面的 `localStorage`（天然按域名隔离）。

---

### ❌ 禁止在全局 `document.addEventListener('mouseover')` 里用 `e.target` 处理 shadow DOM
```js
// 错误示例
document.addEventListener('mouseover', e => {
  const t = e.target; // shadow DOM 里的事件会被重定向到 shadow host
});
```
**原因**：事件冒泡穿越 shadow boundary 时，`e.target` 被重定向为 shadow host 元素，
拿不到真实的 `ruby.hr-char`。

✅ 正确做法：在每个 shadow root 上单独注册 `mouseover` 监听器，
在 shadow root 内部 `e.target` 是真实元素。

---

---

### ❌ 禁止在 `processNode` 里处理"无 CJK"的文本节点
```js
// 错误示例
if (!/[一-鿿㐀-䶿]/.test(text) && !/[a-zA-Z%°℃℉]/.test(text)) return;
// ↑ 纯英文节点（如 "Java"、"API"）会通过这个检查
```
**原因**：中英混排时会产生纯 ASCII 文本节点（如 "Java"）。
`buildFragment` 对这类节点输出完全相同的文本节点 → `replaceChild` 触发 MO → 重新入队 → 无限循环 → **持续 DOM 抖动 + CPU 占用**。

✅ 正确做法：只处理含 CJK 的文本节点（`/[一-鿿㐀-䶿]/.test(text)`）；
且 `buildFragment` 后检查是否有注音元素产生，若无则直接 return，不执行 `replaceChild`。

---

### ❌ 禁止在 `processNode` 里跳过 `visibility: hidden` 的文本节点
```js
// 错误示例
if (cs.visibility === 'hidden') return;
```
**原因**：WeChat 公众号等页面用 `visibility: hidden` 做懒展示（滚动后才变为 visible）。
跳过这些节点 → 初始扫描漏掉 → 后来 WeChat JS 改 visibility 时只是改 CSS，MO 不触发 → 该段落**永远没有拼音**。

✅ 正确做法：只跳过 `font-size: 0px`（完全不参与 layout）；
`visibility: hidden` 仍占位，插入 ruby 元素是安全的。

---

### ❌ 禁止在 `activateRubyMode` 里用 `idle` 模式做初始全量扫描
```js
// 错误示例
processBatch(collect(root)); // 默认 urgent=false → requestIdleCallback
```
**原因**：`requestIdleCallback` 每次可能只给 <2ms，长文章（公众号）需要数秒才扫完，
用户滚到哪里就在哪里才出现拼音，体验很差。

✅ 正确做法：`processBatch(collect(root), null, true)` 用 urgent 模式（16ms/帧），
快速完成注音，不会卡主线程（每帧最多 16ms），同时体感上一次性完成。

---

## 每次修改前自查

- [ ] 有没有新增 `!important` 作用于页面原有元素？
- [ ] 有没有用 `*` 或超宽泛选择器？
- [ ] 有没有修改 NAV_TAGS（特别是移除 `'A'`）？
- [ ] 有没有把页面级设置错误地存入 `chrome.storage.local`？
- [ ] shadow DOM 里的事件处理是否正确（用 shadow root 自己的监听器）？
- [ ] `processNode` 是否还在处理无 CJK 的纯 ASCII 文本节点？
- [ ] `processNode` 是否在 `buildFragment` 无产出时仍执行了 `replaceChild`？
- [ ] `processNode` 是否跳过了 `visibility: hidden` 的节点（不能跳）？
