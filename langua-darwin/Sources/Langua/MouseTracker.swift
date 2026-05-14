import AppKit
import CoreGraphics

/// 全局鼠标监听：光标静止超过 hoverDelay 后触发文字读取，移动时隐藏气泡。
final class MouseTracker {
    var onHover: ((String, CGPoint) -> Void)?
    var onLeave: (() -> Void)?

    private var globalMonitor: Any?
    private var hoverTimer: DispatchWorkItem?
    private var lastPoint: CGPoint = .zero
    private let extractor = TextExtractor()

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
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let text = self.extractor.getText(at: point), !text.isEmpty {
                self.onHover?(text, point)
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
    }
}
