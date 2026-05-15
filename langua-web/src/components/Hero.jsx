import './Hero.css'

// 精简拼音字典（仅供 Hero 演示用）
const PY = {
  '悬':'xuán','停':'tíng','即':'jí','见':'jiàn','拼':'pīn','音':'yīn',
  '阅':'yuè','读':'dú','中':'zhōng','文':'wén','从':'cóng','未':'wèi',
  '如':'rú','此':'cǐ','简':'jiǎn','单':'dān',
  '不':'bù','再':'zài','需':'xū','要':'yào','打':'dǎ','断':'duàn',
  '节':'jié','奏':'zòu','鼠':'shǔ','标':'biāo','滑':'huá','过':'guò',
  '就':'jiù','眼':'yǎn','前':'qián',
  '每':'měi','个':'gè','字':'zì','都':'dōu','能':'néng','说':'shuō',
  '出':'chū','来':'lái','语':'yǔ','言':'yán','的':'de','桥':'qiáo',
  '梁':'liáng','触':'chù','手':'shǒu','可':'kě','及':'jí',
}

function isCJK(ch) {
  const c = ch.charCodeAt(0)
  return c >= 0x4E00 && c <= 0x9FFF
}

const DEMO_TEXT = '阅读中文，从未如此简单。鼠标滑过，拼音就在眼前。每个字都能说出来，语言的桥梁，触手可及。'

export default function Hero() {
  return (
    <section className="hero">
      <div className="aurora">
        <div className="aurora-blob" />
        <div className="aurora-blob" />
        <div className="aurora-blob" />
      </div>

      {/* 浮动汉字装饰 */}
      <div className="hero-floats" aria-hidden="true">
        {['拼','音','汉','字','语','声','调','韵'].map((c, i) => (
          <span key={i} className="hero-float" style={{ '--i': i }}>{c}</span>
        ))}
      </div>

      <div className="hero-content container">
        {/* Badge */}
        <div className="hero-badge hero-anim" style={{animationDelay:'0ms'}}>
          <span className="badge-dot" />
          现已支持 Chrome 扩展 · macOS 客户端
        </div>

        {/* 主标题 */}
        <h1 className="hero-title hero-anim" style={{animationDelay:'100ms'}}>
          悬停即见<span className="grad">拼音</span>
          <br />告别查字典的烦恼
        </h1>

        <p className="hero-desc hero-anim" style={{animationDelay:'200ms'}}>
          将鼠标悬停在任意汉字上，拼音气泡即刻弹出。<br />
          支持多音字消歧、划词标注、全文注音，让中文阅读流畅自然。
        </p>

        {/* 交互演示 */}
        <div className="hero-demo hero-anim" style={{animationDelay:'300ms'}}>
          <div className="demo-label">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
            </svg>
            悬停体验 · 实时演示
          </div>
          <div className="demo-text">
            {[...DEMO_TEXT].map((ch, idx) => {
              const py = PY[ch]
              return isCJK(ch) && py ? (
                <span key={idx} className="demo-char">
                  <span className="demo-bubble">
                    <span className="demo-py">{py}</span>
                  </span>
                  {ch}
                </span>
              ) : (
                <span key={idx} className="demo-punct">{ch}</span>
              )
            })}
          </div>
          <div className="demo-hint">
            {('ontouchstart' in window || navigator.maxTouchPoints > 0)
              ? '将手指放在汉字上试试'
              : '← 将鼠标移到汉字上试试'}
          </div>
        </div>

        {/* CTA */}
        <div className="hero-ctas hero-anim" style={{animationDelay:'400ms'}}>
          <a href="#platforms" className="cta-primary">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M7 10l5 5 5-5M12 15V3"/>
            </svg>
            下载 Chrome 扩展
          </a>
          <a href="#platforms" className="cta-secondary">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
            下载 macOS 客户端
          </a>
        </div>

        {/* 数据统计 */}
        <div className="hero-stats hero-anim" style={{animationDelay:'500ms'}}>
          {[
            { num: '6,500+', label: '常用字收录' },
            { num: '20,900+', label: '完整 CJK 字典' },
            { num: '5 端', label: '全平台覆盖' },
          ].map(s => (
            <div key={s.label} className="hero-stat">
              <span className="stat-num">{s.num}</span>
              <span className="stat-label">{s.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* 向下箭头 */}
      <a href="#features" className="hero-scroll-hint" aria-label="向下滚动">
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M12 5v14M5 12l7 7 7-7"/>
        </svg>
      </a>
    </section>
  )
}
