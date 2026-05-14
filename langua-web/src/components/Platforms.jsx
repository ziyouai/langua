import useInView from '../hooks/useInView'
import './Platforms.css'

const GITHUB = 'https://github.com/ziyouai/langua'

const PLATFORMS = [
  {
    id: 'chrome',
    name: 'Chrome 扩展',
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 0C8.21 0 4.831 1.757 2.632 4.501l3.953 6.848A5.454 5.454 0 0 1 12 6.545h10.691A12 12 0 0 0 12 0zM1.931 5.47A11.943 11.943 0 0 0 0 12c0 6.012 4.42 10.991 10.189 11.864l3.953-6.847a5.45 5.45 0 0 1-6.865-2.29zm13.342 2.166a5.446 5.446 0 0 1 1.45 7.09l.002.001h-.002l-5.344 9.257c.206.01.413.016.621.016 6.627 0 12-5.373 12-12 0-1.54-.29-3.011-.818-4.364zM12 10.545a1.455 1.455 0 1 1 0 2.91 1.455 1.455 0 0 1 0-2.91z"/>
      </svg>
    ),
    status: 'available',
    badge: '免费',
    action: '下载 .crx',
    href: `${GITHUB}/releases/latest`,
    desc: '在任何网页上实时显示拼音，支持全文注音、划词标注',
    steps: ['下载 langua.crx', '打开 chrome://extensions 开启开发者模式', '将 .crx 拖入页面安装'],
  },
  {
    id: 'macos',
    name: 'macOS 客户端',
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
      </svg>
    ),
    status: 'available',
    badge: '免费',
    action: '下载 .dmg',
    href: `${GITHUB}/releases/latest`,
    desc: '系统级拼音标注，覆盖微信、备忘录等所有应用，需 macOS 13+',
    steps: ['下载 .dmg 安装包', '拖入 Applications', '授予辅助功能权限'],
  },
  {
    id: 'windows',
    name: 'Windows 客户端',
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.9-1.801"/>
      </svg>
    ),
    status: 'soon',
    badge: '即将推出',
    desc: '与 macOS 客户端同等功能，全系统范围拼音标注',
  },
  {
    id: 'android',
    name: 'Android',
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M17.523 15.341a.95.95 0 0 1-.948-.953.95.95 0 0 1 .948-.953.95.95 0 0 1 .948.953.95.95 0 0 1-.948.953m-11.046 0a.95.95 0 0 1-.948-.953.95.95 0 0 1 .948-.953.95.95 0 0 1 .948.953.95.95 0 0 1-.948.953m11.4-6.01l1.893-3.276a.392.392 0 0 0-.144-.537.397.397 0 0 0-.541.144l-1.917 3.32A11.547 11.547 0 0 0 12 8.107a11.547 11.547 0 0 0-5.168 1.175L4.915 5.962a.397.397 0 0 0-.541-.144.392.392 0 0 0-.144.537l1.893 3.276C2.562 11.154 0 14.616 0 18.67h24c0-4.054-2.562-7.516-6.123-9.339"/>
      </svg>
    ),
    status: 'soon',
    badge: '即将推出',
    desc: '移动端中文辅助阅读体验，随时随地查看拼音',
  },
  {
    id: 'ios',
    name: 'iOS',
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
      </svg>
    ),
    status: 'soon',
    badge: '即将推出',
    desc: '沉浸式 iOS 阅读体验，App Store 上架后第一时间通知',
  },
]

export default function Platforms() {
  const titleRef = useInView()

  return (
    <section className="section platforms" id="platforms">
      <div className="container">
        <div className="platforms-header">
          <div className="section-tag" ref={titleRef}>✦ 多端覆盖</div>
          <h2 className="section-title">你用什么，就在什么上</h2>
          <p className="section-sub">
            从浏览器到桌面端，从手机到平板，Langua 陪你随时随地阅读中文。
          </p>
        </div>

        <div className="platforms-grid">
          {PLATFORMS.map((p, i) => (
            <PlatformCard key={p.id} platform={p} delay={(i % 3) + 1} />
          ))}
        </div>
      </div>
    </section>
  )
}

function PlatformCard({ platform: p, delay }) {
  const ref = useInView()
  const available = p.status === 'available'

  return (
    <div ref={ref} className={`platform-card fade-up delay-${delay} ${available ? '' : 'platform-card--soon'}`}>
      <div className="platform-icon">{p.icon}</div>
      <div className="platform-badge">{p.badge}</div>
      <h3 className="platform-name">{p.name}</h3>
      <p className="platform-desc">{p.desc}</p>

      {available && p.steps && (
        <ol className="platform-steps">
          {p.steps.map((s, i) => (
            <li key={i}><span>{i + 1}</span>{s}</li>
          ))}
        </ol>
      )}

      {available ? (
        <a href={p.href} target="_blank" rel="noopener noreferrer" className="platform-btn">
          {p.action}
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <path d="M7 17L17 7M17 7H7M17 7v10"/>
          </svg>
        </a>
      ) : (
        <div className="platform-coming">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>
          </svg>
          开发中
        </div>
      )}

      {!available && <div className="platform-frosted" />}
    </div>
  )
}
