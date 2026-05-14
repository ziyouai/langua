import AppKit
import CoreGraphics

/// 全局鼠标监听：光标静止超过 hoverDelay 后触发文字读取，移动时隐藏气泡。
final class MouseTracker {
    /// text, 光标点, 命中元素的 AppKit frame（可选，供气泡精确定位）
    /// 始终在主线程回调。
    var onHover: ((String, CGPoint, CGRect?) -> Void)?
    var onLeave: (() -> Void)?

    private var globalMonitor: Any?
    private var hoverTimer: DispatchWorkItem?
    private var lastPoint: CGPoint = .zero
    private let extractor = TextExtractor()

    /// 竞态保护计数器。
    /// 写：主线程（cancelPending）；读授权：也必须在主线程（见下文）。
    private var currentGeneration: Int = 0

    // 移动超过 4pt 认为"在移动"，取消待展示的气泡
    private let moveThreshold: CGFloat = 4.0

    func start() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        ) { [weak self] _ in
            self?.handleMove()
        }
    }

    func stop() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        cancelPending()
        onLeave?()
    }

    // MARK: - Private

    private func handleMove() {
        let pt = NSEvent.mouseLocation
        let dx = pt.x - lastPoint.x
        let dy = pt.y - lastPoint.y
        let moved = (dx * dx + dy * dy) > (moveThreshold * moveThreshold)

        if moved {
            cancelPending()
            onLeave?()
            lastPoint = pt
        }

        scheduleHover(at: pt)
    }

    private func scheduleHover(at point: CGPoint) {
        cancelPending()
        let delay = AppState.shared.hoverDelayMs / 1000.0
        let generation = currentGeneration

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // 快速预检（后台线程，非权威，仅减少不必要的 AX 调用）
            guard self.currentGeneration == generation else { return }

            guard let text = self.extractor.getText(at: point), !text.isEmpty else { return }
            let frame = self.extractor.lastElementFrame

            // 权威检查必须在主线程（与 cancelPending 的写操作同线程，
            // 避免 ARM 弱内存序导致旧值被读取）
            DispatchQueue.main.async { [weak self] in
                guard let self, self.currentGeneration == generation else { return }
                self.onHover?(text, point, frame)
            }
        }
        hoverTimer = item
        DispatchQueue.global(qos: .userInteractive).asyncAfter(
            deadline: .now() + delay, execute: item
        )
    }

    private func cancelPending() {
        hoverTimer?.cancel()
        hoverTimer = nil
        currentGeneration &+= 1   // 溢出安全递增，使所有在途任务失效
    }
}
