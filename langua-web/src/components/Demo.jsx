import { useState } from 'react'
import useInView from '../hooks/useInView'
import './Demo.css'

const base = import.meta.env.BASE_URL

const TABS = [
  {
    id: 'hover',
    label: '悬停拼音',
    icon: '🖱️',
    desc: '鼠标移到任意汉字上，拼音气泡即刻弹出，不打断阅读节奏',
    screenshot: `${base}screenshots/hover.png`,
  },
  {
    id: 'fulltext',
    label: '全文注音',
    icon: '📖',
    desc: '一键开启全文模式，每个汉字上方实时显示拼音，滚动按需加载',
    screenshot: `${base}screenshots/fulltext.png`,
  },
  {
    id: 'macos-menu',
    label: 'macOS 菜单栏',
    icon: '🖥️',
    desc: '常驻菜单栏，一键开关悬停拼音与划词拼音，还可调节悬停延迟',
    screenshot: `${base}screenshots/macos-menu.png`,
  },
  {
    id: 'macos',
    label: 'macOS 悬停',
    icon: '✨',
    desc: '系统级拼音气泡，覆盖微信、备忘录、字友等任意原生应用',
    screenshot: `${base}screenshots/macos.png`,
  },
]

export default function Demo() {
  const [active, setActive] = useState('hover')
  const titleRef = useInView()
  const tab = TABS.find(t => t.id === active)

  return (
    <section className="section demo" id="demo">
      <div className="container">
        <div className="demo-header">
          <div className="section-tag" ref={titleRef}>✦ 效果演示</div>
          <h2 className="section-title">看见即所得</h2>
          <p className="section-sub">四种真实场景，覆盖你所有的中文阅读需求。</p>
        </div>

        <div className="demo-tabs">
          {TABS.map(t => (
            <button
              key={t.id}
              className={`demo-tab ${active === t.id ? 'demo-tab--active' : ''}`}
              onClick={() => setActive(t.id)}
            >
              <span>{t.icon}</span>
              <span>{t.label}</span>
            </button>
          ))}
        </div>

        <div className="demo-stage">
          <div className="demo-stage-desc">{tab.desc}</div>
          <div className={`demo-screen ${tab.id === 'macos-menu' ? 'demo-screen--compact' : ''}`}>
            <ScreenshotImg tab={tab} />
          </div>
        </div>
      </div>
    </section>
  )
}

function ScreenshotImg({ tab }) {
  const [loaded, setLoaded] = useState(false)
  const [error, setError] = useState(false)

  if (error) {
    return (
      <div className="demo-placeholder">
        <span className="demo-placeholder-icon">{tab.icon}</span>
        <span className="demo-placeholder-text">{tab.label} · 截图即将上传</span>
      </div>
    )
  }

  return (
    <>
      {!loaded && (
        <div className="demo-placeholder">
          <span className="demo-placeholder-icon demo-placeholder-icon--spin">⏳</span>
        </div>
      )}
      <img
        src={tab.screenshot}
        alt={tab.label}
        className="demo-screenshot"
        style={{ display: loaded ? 'block' : 'none' }}
        onLoad={() => setLoaded(true)}
        onError={() => setError(true)}
      />
    </>
  )
}
