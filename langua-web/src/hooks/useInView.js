import { useEffect, useRef } from 'react'

export default function useInView(options = {}) {
  const ref = useRef(null)

  useEffect(() => {
    const el = ref.current
    if (!el) return

    const show = () => el.classList.add('visible')

    // 兜底：2s 后无论如何显示，防止 observer 时序问题导致永远不可见
    const fallback = setTimeout(show, 2000)

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          show()
          clearTimeout(fallback)
          observer.unobserve(el)
        }
      },
      { threshold: 0.01, ...options }  // 极低阈值，只要露出一点就触发
    )
    observer.observe(el)
    return () => { observer.disconnect(); clearTimeout(fallback) }
  }, [])

  return ref
}
