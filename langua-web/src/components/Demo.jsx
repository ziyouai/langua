import { useState, useEffect } from 'react'
import useInView from '../hooks/useInView'
import './Demo.css'

const TABS = [
  { id: 'hover',     label: '悬停拼音', icon: '🖱️', desc: '鼠标移到任意汉字上，拼音气泡即刻弹出，不打断阅读节奏' },
  { id: 'fulltext',  label: '全文注音', icon: '📖', desc: '一键全文标注，每个汉字上方实时显示拼音，让阅读流畅自然' },
  { id: 'selection', label: '划词拼音', icon: '✂️', desc: '选中任意词句，拼音气泡立即弹出，浏览器与原生应用全覆盖' },
]

// 悬停演示文本
const HOVER_CHARS = [
  { ch: '中', py: 'zhōng' }, { ch: '华', py: 'huá' }, { ch: '文', py: 'wén' }, { ch: '化', py: 'huà' },
  { ch: '博', py: 'bó' },   { ch: '大', py: 'dà' },   { ch: '精', py: 'jīng' },{ ch: '深', py: 'shēn' },
  { ch: '，', py: '' },
  { ch: '悬', py: 'xuán' }, { ch: '停', py: 'tíng' }, { ch: '即', py: 'jí' }, { ch: '见', py: 'jiàn' },
  { ch: '拼', py: 'pīn' },  { ch: '音', py: 'yīn' },
]

// 全文注音演示（春晓）
const FULLTEXT_LINES = [
  [{ ch:'春',py:'chūn'},{ch:'眠',py:'mián'},{ch:'不',py:'bù'},{ch:'觉',py:'jué'},{ch:'晓',py:'xiǎo'},{ch:'，',py:''}],
  [{ ch:'处',py:'chù'},{ch:'处',py:'chù'},{ch:'闻',py:'wén'},{ch:'啼',py:'tí'},{ch:'鸟',py:'niǎo'},{ch:'。',py:''}],
  [{ ch:'夜',py:'yè'},{ch:'来',py:'lái'},{ch:'风',py:'fēng'},{ch:'雨',py:'yǔ'},{ch:'声',py:'shēng'},{ch:'，',py:''}],
  [{ ch:'花',py:'huā'},{ch:'落',py:'luò'},{ch:'知',py:'zhī'},{ch:'多',py:'duō'},{ch:'少',py:'shǎo'},{ch:'。',py:''}],
]

// 划词演示：选中「知己」
const SEL_BEFORE = [{ch:'海',py:'hǎi'},{ch:'内',py:'nèi'},{ch:'存',py:'cún'}]
const SEL_PHRASE = [{ch:'知',py:'zhī'},{ch:'己',py:'jǐ'}]
const SEL_AFTER  = [{ch:'，',py:''},{ch:'天',py:'tiān'},{ch:'涯',py:'yá'},{ch:'若',py:'ruò'},{ch:'比',py:'bǐ'},{ch:'邻',py:'lín'},{ch:'。',py:''}]

export default function Demo() {
  const [active, setActive] = useState('hover')
  const titleRef = useInView()

  return (
    <section className="section demo" id="demo">
      <div className="container">
        <div className="demo-header">
          <div className="section-tag" ref={titleRef}>✦ 效果演示</div>
          <h2 className="section-title">看见即所得</h2>
          <p className="section-sub">三种核心功能，直接在页面上感受真实效果。</p>
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
          <div className="demo-stage-desc">{TABS.find(t => t.id === active).desc}</div>
          <div className="demo-live">
            <div className="demo-live-bar">
              <span /><span /><span />
            </div>
            <div className="demo-live-body">
              {active === 'hover'     && <HoverDemo />}
              {active === 'fulltext'  && <FulltextDemo key="ft" />}
              {active === 'selection' && <SelectionDemo />}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

/* ── 悬停拼音 ── */
function HoverDemo() {
  const cjkIndices = HOVER_CHARS.reduce((acc, c, i) => { if (c.py) acc.push(i); return acc }, [])
  const [step, setStep] = useState(0)

  useEffect(() => {
    const id = setInterval(() => setStep(s => (s + 1) % cjkIndices.length), 700)
    return () => clearInterval(id)
  }, [])

  const activeIdx = cjkIndices[step]

  return (
    <div className="demo-hover-wrap">
      <div className="demo-hint-label">— 自动模拟鼠标悬停 —</div>
      <div className="demo-hover-text">
        {HOVER_CHARS.map((c, i) =>
          c.py ? (
            <span key={i} className={`dlc ${i === activeIdx ? 'dlc--on' : ''}`}>
              <span className={`dlc-bubble ${i === activeIdx ? 'dlc-bubble--show' : ''}`}>{c.py}</span>
              {c.ch}
            </span>
          ) : (
            <span key={i} className="dlc-punct">{c.ch}</span>
          )
        )}
      </div>
    </div>
  )
}

/* ── 全文注音 ── */
function FulltextDemo() {
  const [on, setOn] = useState(false)

  useEffect(() => {
    const t = setTimeout(() => setOn(true), 200)
    return () => clearTimeout(t)
  }, [])

  return (
    <div className="demo-ft-wrap">
      <div className="demo-hint-label">— 全文拼音标注 —</div>
      <div className="demo-ft-poem">
        {FULLTEXT_LINES.map((line, li) => (
          <div key={li} className="demo-ft-line">
            {line.map((c, ci) =>
              c.py ? (
                <span key={ci} className="dfc">
                  <span
                    className={`dfc-py ${on ? 'dfc-py--on' : ''}`}
                    style={{ transitionDelay: `${(li * 6 + ci) * 55}ms` }}
                  >{c.py}</span>
                  <span className="dfc-ch">{c.ch}</span>
                </span>
              ) : (
                <span key={ci} className="dlc-punct">{c.ch}</span>
              )
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

/* ── 划词拼音 ── */
const CYCLE = 3600
function SelectionDemo() {
  const [phase, setPhase] = useState(0)

  useEffect(() => {
    const start = Date.now()
    const id = setInterval(() => {
      const ms = (Date.now() - start) % CYCLE
      setPhase(ms < 900 ? 0 : ms < 1500 ? 1 : ms < 2900 ? 2 : 3)
    }, 80)
    return () => clearInterval(id)
  }, [])

  const selected = phase === 1 || phase === 2
  const bubbleOn  = phase === 2
  const bubbleFade = phase === 3

  return (
    <div className="demo-sel-wrap">
      <div className="demo-hint-label">— 自动模拟划词选中 —</div>
      <div className="demo-sel-text">
        {SEL_BEFORE.map((c, i) => <span key={i} className="dsc">{c.ch}</span>)}
        <span className="dsp">
          {bubbleOn && (
            <span className={`dsp-bubble ${bubbleFade ? 'dsp-bubble--fade' : ''}`}>
              {SEL_PHRASE.map(c => c.py).join('  ')}
            </span>
          )}
          {SEL_PHRASE.map((c, i) => (
            <span key={i} className={`dsc ${selected ? 'dsc--sel' : ''}`}>{c.ch}</span>
          ))}
        </span>
        {SEL_AFTER.map((c, i) => <span key={i} className="dsc">{c.ch}</span>)}
      </div>
    </div>
  )
}
