import AppKit
import CoreGraphics

/// 全局鼠标监听：光标静止超过 hoverDelay 后触发文字读取，移动时隐藏气泡。
final class MouseTracker {
    /// text, 光标点, 命中元素的 AppKit frame（可选，供气泡精确定位）
    var onHover: ((String, CGPoint, CGRect?) -> Void)?
    var onLeave: (() -> Void)?

    private var globalMonitor: Any?
    private var hoverTimer: DispatchWorkItem?
    private var lastPoint: CGPoint = .zero
    private let extractor = TextExtractor()

    // 竞态保护：每次移动/取消时递增，后台任务完成前先比对，过期就丢弃
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
        let generation = currentGeneration          // 捕获当前代号
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // 提取前先检查：若光标已移走则放弃
            guard self.currentGeneration == generation else { return }
            if let text = self.extractor.getText(at: point), !text.isEmpty {
                let frame = self.extractor.lastElementFrame
                // 提取后再检查一次（getText 可能耗时较长）
                guard self.currentGeneration == generation else { return }
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
