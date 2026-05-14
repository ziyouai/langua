import './Footer.css'

const GITHUB = 'https://github.com/ziyouai/langua'

export default function Footer() {
  return (
    <footer className="footer">
      <div className="container footer-inner">
        <div className="footer-brand">
          <div className="footer-logo">
            <img src={`${import.meta.env.BASE_URL}logo.png`} alt="Langua" />
            <span>Langua <em>懒瓜</em></span>
          </div>
          <p className="footer-tagline">悬停即见拼音，让中文阅读更自然。</p>
          <div className="footer-socials">
            <a href={GITHUB} target="_blank" rel="noopener noreferrer" className="footer-social" aria-label="GitHub">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/>
              </svg>
            </a>
          </div>
        </div>

        <div className="footer-links">
          <div className="footer-col">
            <h4>产品</h4>
            <a href="#features">功能介绍</a>
            <a href="#demo">效果演示</a>
            <a href="#platforms">下载安装</a>
          </div>
          <div className="footer-col">
            <h4>开源</h4>
            <a href={GITHUB} target="_blank" rel="noopener noreferrer">GitHub 仓库</a>
            <a href={`${GITHUB}/issues`} target="_blank" rel="noopener noreferrer">问题反馈</a>
            <a href={`${GITHUB}/releases`} target="_blank" rel="noopener noreferrer">版本更新</a>
          </div>
          <div className="footer-col">
            <h4>平台</h4>
            <a href="#platforms">Chrome 扩展</a>
            <a href="#platforms">macOS 客户端</a>
            <a href="#platforms">Windows（即将）</a>
          </div>
        </div>
      </div>

      <div className="footer-bottom">
        <div className="container footer-bottom-inner">
          <span>© 2025 Langua · MIT License</span>
          <a href={GITHUB} target="_blank" rel="noopener noreferrer" className="footer-gh-link">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/>
            </svg>
            ziyouai/langua
          </a>
        </div>
      </div>
    </footer>
  )
}
