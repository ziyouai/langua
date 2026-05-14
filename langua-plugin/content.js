/**
 * langua-plugin — content script
 * 核心思路：在页面加载时把每个汉字包进 <ruby class="hr-char">，
 * 鼠标 mouseover 触发悬停气泡；body.hr-ruby-mode 时 <rt> 可见。
 * 全文拼音模式：随滚动懒加载 viewport ±400px 范围内的内容。
 */
(function () {
  'use strict';

  // ── 不处理的标签 ──────────────────────────────────────────────
  const SKIP_TAGS = new Set([
    'SCRIPT','STYLE','NOSCRIPT','TEXTAREA','INPUT',
    'SELECT','BUTTON','PRE','CODE','KBD','MATH','SVG',
    'RUBY','RT','RP',
  ]);

  // ── 气泡 DOM ──────────────────────────────────────────────────
  const bubble = document.createElement('div');
  bubble.id = 'hr-bubble';
  bubble.innerHTML = '<span id="hr-top"></span><span id="hr-bot"></span>';
  document.documentElement.appendChild(bubble);
  const elTop = document.getElementById('hr-top');
  const elBot = document.getElementById('hr-bot');

  function show(rect, top, bot, type) {
    elTop.textContent = top;
    elBot.textContent = bot;
    bubble.dataset.type = type;

    const vw = window.innerWidth;
    // 水平居中于目标字符，但夹紧到视口内（估算气泡宽约 130px）
    let cx = rect.left + rect.width / 2;
    cx = Math.max(135, Math.min(vw - 135, cx));
    bubble.style.left = cx + 'px';

    // 若字符距视口顶部太近，气泡显示在字符下方；否则显示在上方
    if (rect.top < 70) {
      bubble.style.top = (rect.bottom) + 'px';
      bubble.classList.add('hr-flip');
    } else {
      bubble.style.top = rect.top + 'px';
      bubble.classList.remove('hr-flip');
    }

    bubble.classList.add('hr-on');
  }
  function hide() {
    bubble.classList.remove('hr-on');
    bubble.classList.remove('hr-flip');
  }

  // ── 鼠标事件 ──────────────────────────────────────────────────
  let enabled  = true;
  let rubyMode = false;

  // 共享处理逻辑：光 DOM 和各 shadow root 都复用这一个函数
  function handleHover(t) {
    if (!enabled) return;
    if (!t || !t.classList) { hide(); return; }
    if (t.classList.contains('hr-char')) {
      const py = t.dataset.py;
      const ch = t.dataset.ch || t.textContent.replace(/\s/g, '').charAt(0);
      if (py) show(t.getBoundingClientRect(), py, ch, 'pinyin');
    } else if (t.classList.contains('hr-unit')) {
      const rd = t.dataset.reading;
      if (rd) show(t.getBoundingClientRect(), rd, t.textContent, 'unit');
    } else if (!t.closest?.('#hr-bubble')) {
      hide();
    }
  }

  // 光 DOM 监听
  document.addEventListener('mouseover', e => handleHover(e.target), { passive: true });

  document.addEventListener('mouseleave', hide, { passive: true });
  document.addEventListener('scroll', hide, { passive: true, capture: true });

  // ── 设置读写（全局用 chrome.storage，当前页用 localStorage）────
  // ⚠️  当前页设置必须写 localStorage，不能写 chrome.storage.local
  //     chrome.storage.local 是全扩展共享的，写进去会影响所有页面（见 RULES.md）
  const LS_EN   = 'langua_enabled';
  const LS_RUBY = 'langua_rubyMode';

  // 读取生效设置：localStorage 优先（页面覆盖），否则用全局
  function loadEffectiveSettings(callback) {
    chrome.storage.local.get(['enabled', 'rubyMode'], global => {
      const lsEn   = localStorage.getItem(LS_EN);
      const lsRuby = localStorage.getItem(LS_RUBY);
      const hasPageOverride = lsEn !== null || lsRuby !== null;
      callback({
        enabled:         hasPageOverride ? lsEn   !== 'false' : global.enabled  !== false,
        rubyMode:        hasPageOverride ? lsRuby === 'true'  : global.rubyMode === true,
        hasPageOverride,
      });
    });
  }

  function applyEff(s) {
    enabled = s.enabled;
    if (!enabled) hide();
    if (s.rubyMode && !rubyMode) activateRubyMode();
    else if (!s.rubyMode && rubyMode) deactivateRubyMode();
    rubyMode = s.rubyMode;
    updateFloatBtn();
    updateFloatPanel();
  }

  // 初始加载
  loadEffectiveSettings(applyEff);

  // 消息处理
  chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (msg.type === 'GET_SETTINGS') {
      loadEffectiveSettings(s => sendResponse(s));
      return true; // 异步 sendResponse
    }
    if (msg.type === 'SET_SETTINGS') {
      if (msg.scope === 'page') {
        localStorage.setItem(LS_EN,   String(msg.enabled));
        localStorage.setItem(LS_RUBY, String(msg.rubyMode));
      } else {
        // 全局：清除页面覆盖，写全局
        localStorage.removeItem(LS_EN);
        localStorage.removeItem(LS_RUBY);
        chrome.storage.local.set({ enabled: msg.enabled, rubyMode: msg.rubyMode });
      }
      loadEffectiveSettings(s => { applyEff(s); sendResponse(s); });
      return true;
    }
  });

  // ── 悬浮按钮 ─────────────────────────────────────────────────
  let floatBtn, floatPanel;
  let isDragging = false, dragOffX = 0, dragOffY = 0, dragMoved = false;

  function createFloatButton() {
    // 按钮
    floatBtn = document.createElement('div');
    floatBtn.id = 'hr-float-btn';
    floatBtn.innerHTML = '文';
    document.documentElement.appendChild(floatBtn);

    // 面板
    floatPanel = document.createElement('div');
    floatPanel.id = 'hr-float-panel';
    floatPanel.innerHTML = `
      <div class="hr-fp-title">langua <span style="font-size:11px;font-weight:400;color:#7ee8fa99;">懒瓜</span></div>
      <div class="hr-fp-scope">
        <button class="hr-fp-sb" data-s="global">全局</button>
        <button class="hr-fp-sb" data-s="page">当前页</button>
      </div>
      <div class="hr-fp-row">
        <span>悬停拼音</span>
        <label class="hr-fp-sw"><input type="checkbox" id="hr-fp-tog"><span class="hr-fp-track"></span></label>
      </div>
      <div class="hr-fp-row">
        <span>全文拼音</span>
        <label class="hr-fp-sw"><input type="checkbox" id="hr-fp-ruby"><span class="hr-fp-track"></span></label>
      </div>`;
    document.documentElement.appendChild(floatPanel);

    // 恢复位置
    chrome.storage.local.get(['floatPos'], r => {
      if (r.floatPos) {
        floatBtn.style.left = r.floatPos.x + 'px';
        floatBtn.style.top  = r.floatPos.y + 'px';
        floatBtn.style.right = 'auto';
        floatBtn.style.transform = 'none';
      }
      updateFloatBtn();
      updateFloatPanel();
    });

    // 拖拽
    floatBtn.addEventListener('mousedown', e => {
      if (e.button !== 0) return;
      isDragging = true; dragMoved = false;
      const rect = floatBtn.getBoundingClientRect();
      dragOffX = e.clientX - rect.left;
      dragOffY = e.clientY - rect.top;
      e.preventDefault();
    });
    document.addEventListener('mousemove', e => {
      if (!isDragging) return;
      dragMoved = true;
      let x = e.clientX - dragOffX;
      let y = e.clientY - dragOffY;
      const bw = floatBtn.offsetWidth, bh = floatBtn.offsetHeight;
      x = Math.max(0, Math.min(window.innerWidth  - bw, x));
      y = Math.max(0, Math.min(window.innerHeight - bh, y));
      floatBtn.style.left = x + 'px';
      floatBtn.style.top  = y + 'px';
      floatBtn.style.right = 'auto';
      floatBtn.style.transform = 'none';
      positionPanel();
    });
    document.addEventListener('mouseup', () => {
      if (!isDragging) return;
      isDragging = false;
      if (dragMoved) {
        const rect = floatBtn.getBoundingClientRect();
        chrome.storage.local.set({ floatPos: { x: rect.left, y: rect.top } });
      } else {
        togglePanel();
      }
    });

    // 面板开关控件
    document.getElementById('hr-fp-tog').addEventListener('change', function() {
      saveFloatSettings(this.checked, document.getElementById('hr-fp-ruby').checked);
    });
    document.getElementById('hr-fp-ruby').addEventListener('change', function() {
      saveFloatSettings(document.getElementById('hr-fp-tog').checked, this.checked);
    });
    floatPanel.querySelectorAll('.hr-fp-sb').forEach(btn => {
      btn.addEventListener('click', () => {
        const s = btn.dataset.s;
        loadEffectiveSettings(cur => {
          if (s === 'page') {
            // 把当前生效值写入 localStorage，激活页面覆盖
            localStorage.setItem(LS_EN,   String(cur.enabled));
            localStorage.setItem(LS_RUBY, String(cur.rubyMode));
          } else {
            // 清除 localStorage 覆盖，回归全局
            localStorage.removeItem(LS_EN);
            localStorage.removeItem(LS_RUBY);
          }
          loadEffectiveSettings(applyEff);
        });
      });
    });

    // 点击面板外关闭
    document.addEventListener('mousedown', e => {
      if (floatPanel.style.display === 'block' &&
          !floatPanel.contains(e.target) && e.target !== floatBtn) {
        floatPanel.style.display = 'none';
      }
    });
  }

  function togglePanel() {
    if (floatPanel.style.display === 'block') {
      floatPanel.style.display = 'none';
    } else {
      floatPanel.style.display = 'block';
      updateFloatPanel();
      positionPanel();
    }
  }

  function positionPanel() {
    const br = floatBtn.getBoundingClientRect();
    const pw = 190, ph = 150;
    const GAP = 14; // 面板与按钮之间的间距
    // 面板显示在按钮左侧，若空间不足则显示在右侧
    let px = br.left - pw - GAP;
    if (px < 8) px = br.right + GAP;
    let py = br.top + (br.height - ph) / 2;
    py = Math.max(8, Math.min(window.innerHeight - ph - 8, py));
    floatPanel.style.left = px + 'px';
    floatPanel.style.top  = py + 'px';
  }

  function updateFloatBtn() {
    if (!floatBtn) return;
    floatBtn.classList.toggle('hr-disabled', !enabled);
  }

  function updateFloatPanel() {
    if (!floatPanel) return;
    loadEffectiveSettings(s => {
      const scope = s.hasPageOverride ? 'page' : 'global';
      floatPanel.querySelectorAll('.hr-fp-sb').forEach(b => {
        b.classList.toggle('active', b.dataset.s === scope);
      });
      document.getElementById('hr-fp-tog').checked  = s.enabled;
      document.getElementById('hr-fp-ruby').checked = s.rubyMode;
    });
  }

  function saveFloatSettings(en, rm) {
    const hasPageOverride = localStorage.getItem(LS_EN) !== null
                         || localStorage.getItem(LS_RUBY) !== null;
    if (hasPageOverride) {
        localStorage.setItem(LS_EN,   String(en));
        localStorage.setItem(LS_RUBY, String(rm));
        loadEffectiveSettings(applyEff);
    } else {
      chrome.storage.local.get(['pageSettings', 'scope'], r => {
      const scope = r.scope || 'global';
      if (scope === 'page') {
        loadEffectiveSettings(applyEff);
      } else {
        chrome.storage.local.set({ enabled: en, rubyMode: rm }, () =>
          loadEffectiveSettings(applyEff));
      }
    });
    }
  }

  // ── 判断文字颜色是否接近透明/白色（不适合显示全文拼音）────────
  // 如果文字颜色亮度很高（接近白色），说明是反色文字，全文注音会干扰排版
  function isInvisibleText(cs) {
    if (!cs) return false;
    const color = cs.color; // e.g. "rgb(255, 255, 255)" or "rgba(255,255,255,0)"
    if (!color) return false;
    // 解析 rgba
    const m = color.match(/rgba?\(\s*(\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\s*\)/);
    if (!m) return false;
    const r = +m[1], g = +m[2], b = +m[3], a = m[4] !== undefined ? +m[4] : 1;
    // 完全透明 → 跳过全文注音
    if (a < 0.1) return true;
    // 感知亮度（BT.601）> 220 → 近白色文字
    const brightness = 0.299 * r + 0.587 * g + 0.114 * b;
    return brightness > 220;
  }

  // ── 全文拼音模式：语义判断——是否为"阅读内容" ────────────────
  // 明确是正文内容的标签（需无 NAV 祖先才生效）
  const CONTENT_TAGS = new Set([
    'P','H1','H2','H3','H4','H5','H6',
    'ARTICLE','BLOCKQUOTE','MAIN','SECTION',
    'LI','DD','TD','TH','FIGCAPTION',
    // LI/SECTION 保留：WeChat 文章用 section+li 组织正文
    // 全祖先链检查会排除 <nav>/<aside> 内的 <li>，不会误触导航
  ]);
  // 一旦祖先链中出现这些标签 → 全文模式不显示注音（readable=false），
  // 但 ruby 元素仍会创建，悬停气泡依然生效。
  // ⚠️  'A' 必须保留：链接/菜单文字不显示全文注音（见 RULES.md）
  const NAV_TAGS = new Set([
    'NAV','HEADER','FOOTER','ASIDE','MENU','DIALOG','A',
  ]);
  // ARIA role 同理
  const NAV_ROLES = new Set([
    'navigation','banner','contentinfo','complementary',
    'button','tab','menu','menubar','menuitem',
    'tooltip','dialog','alertdialog',
  ]);

  function isReadingContent(textNode) {
    const cjkCount = (textNode.textContent.match(/[一-鿿㐀-䶿]/g) || []).length;
    if (cjkCount === 0) return false;

    let node = textNode.parentElement;

    // 从里向外找最近的语义容器，遇到第一个有意义的标签就停下来判断：
    //   • 先遇到 CONTENT 标签（P / H1-H6 / SECTION / ARTICLE …）→ 正文，返回 true
    //   • 先遇到 NAV 标签 / ARIA NAV role（NAV / HEADER / A / role="banner" …）→ 非正文，返回 false
    //
    // ⚠️  RULES: 不能走完整祖先链再判断——旧逻辑会因为 <p> 外层包了带
    //     role="complementary"/"banner" 的容器（WeChat / 知乎常见）而把整段正文排除；
    //     找到 CONTENT 容器后立刻返回 true，不再继续向上。
    while (node && node !== document.body) {
      const tag  = node.tagName;
      const role = node.getAttribute?.('role');

      // 先判断正文标签（H1-H6 同样在 CONTENT_TAGS 里，一并处理）
      if (CONTENT_TAGS.has(tag))           return true;
      // 再判断导航标签 / role
      if (NAV_TAGS.has(tag))               return false;
      if (role && NAV_ROLES.has(role))     return false;

      node = node.parentElement;
    }

    // 未识别容器（div / span 嵌套等）：需要连续 6 个以上 CJK 字符才算正文，
    // 过滤掉短版权声明/标签/时间戳等片段（"版权所有" 4字、"作者：" 2字 等均不满足）
    return /[一-鿿㐀-䶿]{6,}/.test(textNode.textContent);
  }

  // ── 构建 fragment：逐字包裹 CJK，识别单位 ────────────────────
  function buildFragment(text, readable) {
    const tokens = Segmenter.segment(text);
    const pyMap  = {};
    let p = 0;
    for (const tok of tokens) {
      for (let i = 0; i < tok.word.length; i++) {
        const ch = tok.word[i];
        if (isCJK(ch)) {
          pyMap[p] = tok.pinyin[i] || CHAR_DICT[ch] || '';
        }
        p++;
      }
    }

    // 连续 CJK 不足 6 字的文本（版权/标签/时间戳等短片段）标记为 hr-short，
    // CSS 会在全文拼音模式下对 hr-short 不显示拼音（但悬停气泡仍然生效）
    const isShort = !readable && !/[一-鿿㐀-䶿]{6,}/.test(text);

    const frag = document.createDocumentFragment();
    let i = 0;

    while (i < text.length) {
      const ch = text[i];

      if (isCJK(ch)) {
        const py = pyMap[i] || CHAR_DICT[ch] || '';
        if (py) {
          // 使用 <ruby> 元素，内含 <rt class="hr-rt"> 用于全文拼音模式
          const ruby = document.createElement('ruby');
          ruby.className   = isShort ? 'hr-char hr-short' : 'hr-char';
          ruby.dataset.py  = py;
          ruby.dataset.ch  = ch;
          ruby.appendChild(document.createTextNode(ch));
          const rt = document.createElement('rt');
          rt.className    = 'hr-rt';
          rt.textContent  = py;
          ruby.appendChild(rt);
          frag.appendChild(ruby);
        } else {
          appendText(frag, ch);
        }
        i++;

      } else {
        // 单位最长匹配（≥2字符）
        let found = false;
        for (let len = Math.min(15, text.length - i); len >= 2; len--) {
          const cand = text.slice(i, i + len);
          if (UNITS_DICT[cand]) {
            const sp = document.createElement('span');
            sp.className       = 'hr-unit';
            sp.dataset.reading = UNITS_DICT[cand];
            sp.textContent     = cand;
            frag.appendChild(sp);
            i += len;
            found = true;
            break;
          }
        }
        // 单字符特殊单位：%、°、℃、℉
        if (!found && UNITS_DICT[ch] && /[%°℃℉]/.test(ch)) {
          const sp = document.createElement('span');
          sp.className       = 'hr-unit';
          sp.dataset.reading = UNITS_DICT[ch];
          sp.textContent     = ch;
          frag.appendChild(sp);
          found = true;
          i++;
        }
        if (!found) { appendText(frag, ch); i++; }
      }
    }

    return frag;
  }

  function appendText(frag, ch) {
    const last = frag.lastChild;
    // 不追加到 ruby/rt 元素，只追加到文本节点
    if (last && last.nodeType === Node.TEXT_NODE) last.textContent += ch;
    else frag.appendChild(document.createTextNode(ch));
  }

  // ── 处理单个文本节点 ──────────────────────────────────────────
  function processNode(textNode) {
    const text = textNode.textContent;
    if (!text.trim()) return;
    // 必须含 CJK 字符，或含连续拉丁字母（潜在单位缩写）才处理
    // ⚠️  RULES: 纯无字母文本节点跳过（数字/标点）→ 无意义
    //     纯 ASCII 字母节点安全：buildFragment 若无单位匹配则不调用 replaceChild
    //     （hasAnnotation 保护已存在），shouldSkip 拦截已生成 .hr-unit 节点，不会循环
    const hasCJK      = /[一-鿿㐀-䶿]/.test(text);
    const hasLatinSeq = /[A-Za-z]{2,}/.test(text);
    if (!hasCJK && !hasLatinSeq) return;

    const parent = textNode.parentNode;
    if (!parent) return;
    if (shouldSkip(parent)) return;

    // 跳过 font-size:0（彻底不可见，layout 上不占空间）
    // ⚠️  RULES: 不检查 visibility:hidden → visibility 只隐藏渲染，元素仍占位；
    //     WeChat 文章用 visibility:hidden 做懒展示，跳过会导致那些段落永远没有拼音。
    // ⚠️  RULES: 不检查 opacity（动画过渡中临时为0，跳过会漏处理）
    let cs;
    try {
      cs = getComputedStyle(parent);
      if (cs.fontSize === '0px') return; // font-size:0 → 完全隐藏
    } catch (e) {}

    const readable = isReadingContent(textNode) && !isInvisibleText(cs);
    const frag = buildFragment(text, readable);

    // ⚠️  RULES: 若 buildFragment 未产生任何注音/单位元素（纯文本输出）
    //     则不执行 replaceChild，避免触发 MO → 重新入队 → 无限循环
    let hasAnnotation = false;
    for (const child of frag.childNodes) {
      if (child.nodeType === Node.ELEMENT_NODE) { hasAnnotation = true; break; }
    }
    if (!hasAnnotation) return;

    parent.replaceChild(frag, textNode);
  }

  // ── 是否跳过 ──────────────────────────────────────────────────
  function shouldSkip(el) {
    let node = el;
    while (node && node.nodeType === Node.ELEMENT_NODE) {
      if (SKIP_TAGS.has(node.tagName))               return true;
      // ⚠️  不检查 isContentEditable：WeChat 等站点在正文容器上设置 contenteditable="true"
      //     用于划词高亮/标注功能（不是真正的编辑器），isContentEditable 走祖先链会把
      //     整篇正文全部跳过。真正需要跳过的输入控件（textarea/input）已在 SKIP_TAGS 里。
      if (node.id === 'hr-bubble')                   return true;
      if (node.classList?.contains('hr-char'))       return true;
      if (node.classList?.contains('hr-unit'))       return true;
      // 注意：不再检查 aria-hidden，因为评论区容器在加载时可能携带该属性
      // 导致整块新内容被永久跳过；可见性由 processNode 中的 getComputedStyle 保证
      node = node.parentElement;
    }
    return false;
  }

  // ── 收集待处理的文本节点 ──────────────────────────────────────
  function collect(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        if (!n.textContent.trim())    return NodeFilter.FILTER_REJECT;
        if (shouldSkip(n.parentNode)) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      },
    });
    const list = [];
    let n;
    while ((n = walker.nextNode())) list.push(n);
    return list;
  }

  // ── 分批处理 ──────────────────────────────────────────────────
  // urgent=true：MO 触发的新增内容，用 setTimeout 立即处理（≤16ms/帧）
  // urgent=false：初始全页扫描，用 requestIdleCallback 不阻塞页面
  function processBatch(nodes, onDone, urgent = false) {
    let i = 0;
    function tick(deadline) {
      const t0 = performance.now();
      while (i < nodes.length) {
        // 非紧急：用 idle 剩余时间；紧急：每帧最多占 16ms
        if (!urgent && deadline && deadline.timeRemaining() < 2) break;
        if (urgent && performance.now() - t0 > 16) break;
        try { processNode(nodes[i]); } catch (e) {}
        i++;
      }
      if (i < nodes.length) {
        if (urgent) setTimeout(tick, 0);
        else schedule(tick);
      } else if (onDone) onDone();
    }
    if (urgent) setTimeout(tick, 0);
    else schedule(tick);
  }

  function schedule(fn) {
    if (window.requestIdleCallback) requestIdleCallback(fn, { timeout: 500 });
    else setTimeout(fn, 0);
  }

  // ── Shadow DOM 穿透处理 ───────────────────────────────────────
  // Bilibili 等站点将内容放在自定义元素的 open shadow root 里，
  // 普通 TreeWalker / MutationObserver 无法自动穿透，需要手动订阅。
  const observedShadows = new WeakSet();
  const shadowRootList  = [];   // 可遍历列表，用于全文模式开/关时同步样式

  // shadow root 内需要的基础样式（hover 模式始终生效）
  const SHADOW_BASE_CSS = `
ruby.hr-char{display:inline}
.hr-rt{display:none}
.hr-unit{border-bottom:1px dashed rgba(251,191,36,.6);cursor:help}
`;
  // 全文拼音模式追加的样式
  const SHADOW_RUBY_CSS = `
/* 直接包含 ruby 字符的容器：禁止 flex 拉伸 / justify 分散 */
:has(> ruby.hr-char){
  justify-content:flex-start!important;
  text-align:left!important;
  text-align-last:left!important;
  word-spacing:normal!important;
  letter-spacing:normal!important;
}
ruby.hr-char{display:ruby;ruby-align:center;overflow:visible;flex:0 0 auto;align-self:flex-start}
ruby.hr-char .hr-rt{
  display:ruby-text;font-size:14px;color:#7eb8fa;font-weight:500;
  letter-spacing:.5px;font-family:"PingFang SC","Hiragino Sans GB","Microsoft YaHei",sans-serif;
  margin-bottom:4px;padding:0 3px
}
ruby.hr-char.hr-short{display:inline}
ruby.hr-char.hr-short .hr-rt{display:none}
nav ruby.hr-char,header ruby.hr-char,footer ruby.hr-char,
aside ruby.hr-char,menu ruby.hr-char,dialog ruby.hr-char,
a ruby.hr-char,[role="navigation"] ruby.hr-char,
[role="banner"] ruby.hr-char,[role="contentinfo"] ruby.hr-char,
[role="complementary"] ruby.hr-char,[role="button"] ruby.hr-char,
[role="tab"] ruby.hr-char,[role="menu"] ruby.hr-char,
[role="menubar"] ruby.hr-char,[role="menuitem"] ruby.hr-char{display:inline}
nav ruby.hr-char .hr-rt,header ruby.hr-char .hr-rt,footer ruby.hr-char .hr-rt,
aside ruby.hr-char .hr-rt,menu ruby.hr-char .hr-rt,dialog ruby.hr-char .hr-rt,
a ruby.hr-char .hr-rt,[role="navigation"] ruby.hr-char .hr-rt,
[role="banner"] ruby.hr-char .hr-rt,[role="contentinfo"] ruby.hr-char .hr-rt,
[role="complementary"] ruby.hr-char .hr-rt,[role="button"] ruby.hr-char .hr-rt,
[role="tab"] ruby.hr-char .hr-rt,[role="menu"] ruby.hr-char .hr-rt,
[role="menubar"] ruby.hr-char .hr-rt,[role="menuitem"] ruby.hr-char .hr-rt{display:none}
`;

  function injectShadowStyle(sr) {
    if (sr.querySelector('style[data-hr-base]')) return; // 已注入
    const s = document.createElement('style');
    s.setAttribute('data-hr-base', '');
    s.textContent = SHADOW_BASE_CSS;
    sr.prepend(s);
    if (rubyMode) addShadowRubyStyle(sr);
  }

  function addShadowRubyStyle(sr) {
    if (sr.querySelector('style[data-hr-ruby]')) return;
    const s = document.createElement('style');
    s.setAttribute('data-hr-ruby', '');
    s.textContent = SHADOW_RUBY_CSS;
    // ⚠️ 必须 appendChild（放到最后），确保我们的样式在 B 站自身 CSS 之后，
    // 相同优先级时以文档顺序靠后者胜出，!important 才能真正生效。
    sr.appendChild(s);
  }

  function removeShadowRubyStyle(sr) {
    sr.querySelector('style[data-hr-ruby]')?.remove();
  }

  function processShadowRoot(sr) {
    if (!sr || observedShadows.has(sr)) return;
    observedShadows.add(sr);
    shadowRootList.push(sr);
    // 注入样式（替代无法穿透 shadow boundary 的外部 CSS）
    injectShadowStyle(sr);
    // 在 shadow root 内直接监听 mouseover，e.target 是真实元素，无重定向问题
    sr.addEventListener('mouseover', e => handleHover(e.target), { passive: true });
    sr.addEventListener('mouseleave', hide, { passive: true });
    // 处理 shadow root 内已有的文本节点
    const nodes = collect(sr);
    if (nodes.length) processBatch(nodes, null, true);
    // 继续监听 shadow root 内部的动态变化
    mo.observe(sr, { childList: true, subtree: true });
  }

  // 递归扫描 root（Element 或 ShadowRoot）里所有嵌套的 open shadowRoot
  // Bilibili 用双层嵌套：bili-comment-renderer → bili-rich-text，各有自己的 shadow root
  function scanShadowRoots(root) {
    if (!root) return;
    // 如果 root 本身是 Element 且有 shadow root，先处理它自己
    if (root.nodeType === Node.ELEMENT_NODE && root.shadowRoot) {
      processShadowRoot(root.shadowRoot);
      scanShadowRoots(root.shadowRoot); // 递归进入这层 shadow root
    }
    // 再扫 root 子树（querySelectorAll 只看当前层的 light DOM）
    try {
      const children = root.querySelectorAll('*');
      for (const child of children) {
        if (child.shadowRoot) {
          processShadowRoot(child.shadowRoot);
          scanShadowRoots(child.shadowRoot); // 继续递归，处理嵌套 shadow root
        }
      }
    } catch (e) {}
  }

  // ── MutationObserver ─────────────────────────────────────────
  // 批量变更去抖：记录本轮受影响的最近公共容器，延迟 300ms 统一重扫
  // 场景：WeChat 文章 JS 批量替换整个 section 的 innerHTML，
  //       会产生大量 childList 变更，逐元素 collect 可能遗漏某些节点；
  //       统一对受影响根节点做一次完整 collect 更可靠。
  let moTimer = null;
  const moRoots = new Set();

  function flushMoRoots() {
    moTimer = null;
    const toProcess = [];
    for (const root of moRoots) {
      collect(root).forEach(n => toProcess.push(n));
    }
    moRoots.clear();
    if (toProcess.length) processBatch(toProcess, null, true);
  }

  const mo = new MutationObserver(muts => {
    const toProcess = [];
    for (const m of muts) {
      for (const added of m.addedNodes) {
        if (added.nodeType === Node.TEXT_NODE) {
          if (added.textContent.trim() && !shouldSkip(added.parentNode))
            toProcess.push(added);
        } else if (added.nodeType === Node.ELEMENT_NODE) {
          collect(added).forEach(n => toProcess.push(n));
          // Shadow root 可能在元素插入后才异步填充内容，分两次尝试
          setTimeout(() => scanShadowRoots(added), 0);
          setTimeout(() => scanShadowRoots(added), 400);
          // 批量变更：把受影响容器的父节点加入去抖集合，300ms 后统一补扫
          // 这样能捕获 WeChat 等页面批量 innerHTML 替换后遗漏的文本节点
          const rootEl = m.target || added.parentElement;
          if (rootEl && rootEl !== document.body) moRoots.add(rootEl);
        }
      }
    }
    if (toProcess.length) processBatch(toProcess, null, true); // 新增内容优先处理
    // 延迟补扫：在本轮所有变更完成后，对受影响区域再做一次完整扫描
    if (moRoots.size > 0) {
      clearTimeout(moTimer);
      moTimer = setTimeout(flushMoRoots, 300);
    }
  });

  // ── 全文拼音模式：viewport 懒加载 ────────────────────────────
  const VIEWPORT_PAD = 400; // viewport 上下各扩展 400px
  let scrollTimer = null;

  function processViewport() {
    const top    = window.scrollY - VIEWPORT_PAD;
    const bottom = window.scrollY + window.innerHeight + VIEWPORT_PAD;

    // 只收集在视口范围内的文本节点
    const root  = document.body || document.documentElement;
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode(n) {
        if (!n.textContent.trim())    return NodeFilter.FILTER_REJECT;
        if (shouldSkip(n.parentNode)) return NodeFilter.FILTER_REJECT;
        // 粗检父元素是否在视口附近
        const rect = n.parentElement?.getBoundingClientRect();
        if (!rect) return NodeFilter.FILTER_REJECT;
        const absTop = rect.top + window.scrollY;
        if (absTop > bottom || absTop + rect.height < top) return NodeFilter.FILTER_REJECT;
        return NodeFilter.FILTER_ACCEPT;
      },
    });
    const nodes = [];
    let node;
    while ((node = walker.nextNode())) nodes.push(node);
    if (nodes.length) processBatch(nodes);
  }

  // 悬停模式：滚动结束后补扫视口附近的未处理文本节点
  // 场景：WeChat / 知乎等按滚动懒加载段落，MO 有时在内容渲染完成前就触发，
  //       导致 collect(added) 找不到文字；滚动停止 400ms 后再扫一次作为兜底。
  let scrollRescanTimer = null;
  function onScrollRescan() {
    clearTimeout(scrollRescanTimer);
    scrollRescanTimer = setTimeout(() => {
      const root = document.body || document.documentElement;
      // 只收集尚未处理的文本节点（已处理的被 shouldSkip 过滤，不会重复处理）
      processBatch(collect(root), null, true);
    }, 400);
  }
  // 始终监听滚动（悬停模式 + 全文模式均需要），在 init() 里注册
  // deactivateRubyMode 只移除全文模式自己添加的 onScroll，不移除此处的 onScrollRescan

  function onScroll() {
    // 全文拼音模式：按视口范围懒加载（只处理屏幕附近的段落，节省性能）
    if (!rubyMode) return;
    clearTimeout(scrollTimer);
    scrollTimer = setTimeout(processViewport, 200);
  }

  // 补加 hr-readable 类：对已被处理（hr-char 已存在）但 readable=false 的节点，
  // 重新用更新后的 isReadingContent 判断，符合条件的补加 hr-readable。
  // 场景：旧版 isReadingContent 误判 → 段落有 hr-char 但无 hr-readable →
  //       开启全文拼音后仍看不到拼音；此函数修复存量数据，无需重建 DOM。
  function upgradeReadableClass(root) {
    const chars = root.querySelectorAll('ruby.hr-char:not(.hr-readable)');
    for (const ruby of chars) {
      // 取 ruby 内的文本节点来判断（ruby 已替换了原始文本节点，用 ruby 自身即可）
      if (isReadingContent(ruby.firstChild || ruby)) {
        ruby.classList.add('hr-readable');
      }
    }
  }

  function activateRubyMode() {
    document.body.classList.add('hr-ruby-mode');
    // 给已观察的 shadow root 补注 ruby 样式
    for (const sr of shadowRootList) addShadowRubyStyle(sr);
    const root = document.body || document.documentElement;
    // 全页处理：urgent=true（16ms/帧），尽快完成标注，避免用户看到"拼音慢慢出现"
    // ⚠️  RULES: 不用 idle 模式——idle 每次只处理 <2ms，长文章需要数秒才能完成，
    //     用户滚动时会看到段落逐渐出现拼音（看起来像"加载慢"）
    processBatch(collect(root), null, true);
    // 补加 hr-readable：修复已创建但 readable=false 的 ruby 元素
    // （isReadingContent 更新后，旧的误判节点需要回填类名）
    upgradeReadableClass(root);
    scanShadowRoots(root);
    window.addEventListener('scroll', onScroll, { passive: true });
  }

  function deactivateRubyMode() {
    document.body.classList.remove('hr-ruby-mode');
    // 移除所有 shadow root 里的 ruby 样式
    for (const sr of shadowRootList) removeShadowRubyStyle(sr);
    window.removeEventListener('scroll', onScroll);
    // 注意：onScrollRescan 由 init() 全局注册，此处不移除
  }

  // ── 异步加载扩展拼音字典（U+4E00–U+9FFF 全量，索引数组格式）────
  const EXT_START = 0x4E00;

  function applyExtDict(arr) {
    for (let i = 0; i < arr.length; i++) {
      if (arr[i]) {
        const ch = String.fromCharCode(EXT_START + i);
        if (!CHAR_DICT[ch]) CHAR_DICT[ch] = arr[i];
      }
    }
  }

  async function loadExtDict() {
    try {
      // 先查缓存
      const cache = await chrome.storage.local.get(['extDict']);
      if (cache.extDict) { applyExtDict(cache.extDict); return; }

      // 从扩展本地资源加载（比外部 CDN 更可靠，无跨域）
      const url  = chrome.runtime.getURL('pinyin-ext.json');
      const resp = await fetch(url);
      if (!resp.ok) return;
      const arr = await resp.json();
      applyExtDict(arr);

      // 缓存到 storage，避免每次重新 parse
      chrome.storage.local.set({ extDict: arr });
    } catch (e) {}
  }

  // ── 初始化 ────────────────────────────────────────────────────
  function init() {
    const root = document.body || document.documentElement;
    // ⚠️  RULES: 必须用 urgent=true（16ms/帧），不能用 requestIdleCallback：
    //     idle 每帧只处理 <2ms，长文章需要数秒才能完成；
    //     用户在扫描完成前悬停任何段落都看不到拼音，体验严重下降。
    //     WeChat 等动态页面的 idle 时间更少，等待时间可达 10s 以上。
    processBatch(collect(root), null, true);
    // 扫描页面初始存在的 shadow root（如 Bilibili 评论区）
    scanShadowRoots(root);
    mo.observe(root, { childList: true, subtree: true });

    // 悬浮按钮
    createFloatButton();

    // 延迟加载全量字典：不阻塞页面，加载后新出现的字自动有拼音
    loadExtDict();

    // 延迟补扫：WeChat / 单页应用等在 document_idle 之后仍会动态注入内容；
    // MO 能捕获大部分，但对某些 innerHTML 批量替换场景可能有遗漏，
    // 用两轮延迟补扫（1s + 3s）兜底。
    // collect 内部的 shouldSkip 会跳过已处理节点，重复调用无副作用。
    setTimeout(() => processBatch(collect(root), null, true), 1000);
    setTimeout(() => processBatch(collect(root), null, true), 3000);

    // 滚动补扫：WeChat 等站点按滚动懒加载段落，每次滚动停止后主动补扫
    // 无论悬停模式还是全文拼音模式都生效
    window.addEventListener('scroll', onScrollRescan, { passive: true });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();

  function isCJK(ch) {
    const c = ch.charCodeAt(0);
    return (c >= 0x4E00 && c <= 0x9FFF) || (c >= 0x3400 && c <= 0x4DBF);
  }
})();
