import useInView from '../hooks/useInView'
import './Features.css'

const FEATURES = [
  {
    icon: '🖱️',
    title: '悬停拼音气泡',
    desc: '鼠标悬停在任意汉字上，拼音气泡即刻弹出，无需点击，不打断阅读节奏。',
    color: '#7ee8fa',
  },
  {
    icon: '✍️',
    title: '划词逐字标注',
    desc: '拖选一段中文后，气泡逐字对齐显示拼音，非汉字内容原样呈现，混合文本一目了然。',
    color: '#a78bfa',
  },
  {
    icon: '📖',
    title: '全文注音模式',
    desc: '一键切换全文模式，每个汉字上方以 ruby 元素显示拼音，滚动时按需加载，不影响性能。',
    color: '#34d399',
  },
  {
    icon: '🔤',
    title: '多音字智能消歧',
    desc: '基于词语分割算法，结合上下文自动选择正确读音，准确处理"行""重""长"等常见多音字。',
    color: '#fb923c',
  },
  {
    icon: '🏥',
    title: '单位与缩写提示',
    desc: '悬停在 MCV、HbA1c、mmHg 等医学或科学缩写上，气泡直接显示中文全称，无需离页查询。',
    color: '#f472b6',
  },
  {
    icon: '🎚️',
    title: '注音阈值可调',
    desc: '通过滑条控制最少注音字数（默认 6 字），短按钮文字、版权声明等不注音，减少视觉干扰。',
    color: '#fbbf24',
  },
]

export default function Features() {
  const titleRef = useInView()

  return (
    <section className="section features" id="features">
      <div className="container">
        <div className="features-header">
          <div className="section-tag" ref={titleRef}>✦ 核心功能</div>
          <h2 className="section-title">
            为中文阅读<span className="grad">量身打造</span>
          </h2>
          <p className="section-sub">
            六大功能模块，覆盖从学习到专业阅读的全场景需求。
          </p>
        </div>

        <div className="features-grid">
          {FEATURES.map((f, i) => (
            <FeatureCard key={f.title} feature={f} delay={i % 3} />
          ))}
        </div>
      </div>
    </section>
  )
}

function FeatureCard({ feature, delay }) {
  const ref = useInView()
  return (
    <div
      ref={ref}
      className={`feature-card fade-up delay-${delay + 1}`}
      style={{ '--accent': feature.color }}
    >
      <div className="feature-icon">{feature.icon}</div>
      <h3 className="feature-title">{feature.title}</h3>
      <p className="feature-desc">{feature.desc}</p>
      <div className="feature-glow" />
    </div>
  )
}
