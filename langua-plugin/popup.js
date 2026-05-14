const tog       = document.getElementById('tog');
const togRuby   = document.getElementById('tog-ruby');
const btnGlobal = document.getElementById('scope-global');
const btnPage   = document.getElementById('scope-page');
const pageLabel = document.getElementById('page-label');
const mcSlider  = document.getElementById('mc-slider');
const mcVal     = document.getElementById('mc-val');

let currentScope = 'global';
let tabId = null;

// ── 初始化：向 content script 获取当前页实际设置 ──────────────
chrome.tabs.query({ active: true, currentWindow: true }, tabs => {
  tabId = tabs[0]?.id;
  const url = tabs[0]?.url || '';
  try { pageLabel.textContent = '当前页：' + new URL(url).hostname; } catch(e) {}

  chrome.tabs.sendMessage(tabId, { type: 'GET_SETTINGS' }, res => {
    if (chrome.runtime.lastError || !res) return;
    currentScope = res.hasPageOverride ? 'page' : 'global';
    setScope(currentScope);
    tog.checked     = res.enabled;
    togRuby.checked = res.rubyMode;
    if (res.minChars != null) {
      mcSlider.value    = res.minChars;
      mcVal.textContent = res.minChars;
    }
  });
});

// ── 作用域切换 ────────────────────────────────────────────────
btnGlobal.addEventListener('click', () => {
  setScope('global');
  // 清除当前页 localStorage 覆盖，回归全局
  chrome.tabs.sendMessage(tabId, { type: 'SET_SETTINGS', scope: 'global' }, res => {
    if (res) { tog.checked = res.enabled; togRuby.checked = res.rubyMode; }
  });
});

btnPage.addEventListener('click', () => {
  setScope('page');
  // 把当前开关状态写入 localStorage（初始化当前页覆盖）
  chrome.tabs.sendMessage(tabId, {
    type: 'SET_SETTINGS', scope: 'page',
    enabled: tog.checked, rubyMode: togRuby.checked,
  });
});

function setScope(s) {
  currentScope = s;
  btnGlobal.classList.toggle('active', s === 'global');
  btnPage.classList.toggle('active',   s === 'page');
}

// ── 开关变化 ──────────────────────────────────────────────────
tog.addEventListener('change',     () => sendSave());
togRuby.addEventListener('change', () => sendSave());

// ── 注音阈值 ──────────────────────────────────────────────────
mcSlider.addEventListener('input', () => {
  const v = +mcSlider.value;
  mcVal.textContent = v;
  chrome.tabs.sendMessage(tabId, { type: 'SET_MIN_CHARS', value: v });
});

function sendSave() {
  chrome.tabs.sendMessage(tabId, {
    type: 'SET_SETTINGS',
    scope:    currentScope,
    enabled:  tog.checked,
    rubyMode: togRuby.checked,
  });
}
