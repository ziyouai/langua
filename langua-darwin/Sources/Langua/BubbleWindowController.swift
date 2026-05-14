import AppKit
import SwiftUI

/// 悬浮气泡窗口：NSPanel + SwiftUI 内容，跟随鼠标显示，不抢焦点。
///
/// 支持两种显示模式：
///   • hover 模式：鼠标悬停触发，移动时隐藏
///   • selection 模式（划词）：选词触发，优先级更高；
///     移动鼠标不消失，只有再次点击（clearSelection）才隐藏
///
/// 所有公共方法均在主线程调用。
final class BubbleWindowController {
    private let panel: NSPanel
    /// true = 当前显示的是划词气泡，hover 的 show/hide 均被忽略
    private var isSelectionMode = false
    /// 每次 fadeIn 时递增，用于让滞后的 fadeOut completion handler 放弃 orderOut
    private var dismissGeneration = 0

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level           = .floating
        panel.isOpaque        = false
        panel.backgroundColor = .clear
        panel.hasShadow       = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.alphaValue = 0
    }

    // MARK: - Hover 模式（低优先级）

    func show(chars: [AnnotatedChar], near appKitPoint: CGPoint, elementFrame: CGRect? = nil) {
        guard !isSelectionMode else { return }   // 划词期间忽略 hover
        present(chars: chars, near: appKitPoint, elementFrame: elementFrame)
    }

    /// 鼠标移动时隐藏（选词模式下不响应）
    func hide() {
        guard !isSelectionMode else { return }
        fadeOut()
    }

    // MARK: - Selection 模式（高优先级）

    func showForSelection(chars: [AnnotatedChar], near appKitPoint: CGPoint, elementFrame: CGRect? = nil) {
        isSelectionMode = true
        present(chars: chars, near: appKitPoint, elementFrame: elementFrame)
    }

    /// 鼠标点击时清除选词气泡（由 SelectionTracker.mouseDown 触发）
    func clearSelection() {
        isSelectionMode = false
        fadeOut()
    }

    // MARK: - Internal

    private func present(chars: [AnnotatedChar], near appKitPoint: CGPoint, elementFrame: CGRect?) {
        setContent(chars)
        position(near: appKitPoint, elementFrame: elementFrame)
        fadeIn()
    }

    private func setContent(_ chars: [AnnotatedChar]) {
        let view = BubbleView(chars: chars)
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = host
        let fit = host.fittingSize
        panel.setContentSize(NSSize(width: min(fit.width, 800), height: fit.height))
    }

    private func position(near pt: CGPoint, elementFrame: CGRect? = nil) {
        let size   = panel.frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pt) }) ?? NSScreen.main
        let sf     = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let gap: CGFloat = 8

        var origin: NSPoint

        if let ef = elementFrame {
            let elemTop = ef.maxY
            let elemBot = ef.minY
            let aboveY = elemTop + gap
            if aboveY + size.height <= sf.maxY - 4 {
                origin = NSPoint(x: pt.x - size.width / 2, y: aboveY)
            } else {
                origin = NSPoint(x: pt.x - size.width / 2, y: elemBot - size.height - gap)
            }
        } else {
            let offset: CGFloat = 12
            origin = NSPoint(x: pt.x + offset, y: pt.y + offset)
            if origin.y + size.height > sf.maxY - 8 {
                origin.y = pt.y - size.height - offset
            }
        }

        origin.x = max(sf.minX + 8, min(origin.x, sf.maxX - size.width - 8))
        origin.y = max(sf.minY + 8, min(origin.y, sf.maxY - size.height - 8))

        panel.setFrameOrigin(origin)
    }

    private func fadeIn() {
        // 递增代号：让任何已排队的 fadeOut completion handler 失效，不再执行 orderOut
        dismissGeneration &+= 1
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private func fadeOut() {
        let gen = dismissGeneration   // 捕获当前代号
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.10
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.dismissGeneration == gen else { return }
            // 代号未变 → 期间没有调用过 fadeIn → 安全 orderOut
            self.panel.orderOut(nil)
        }
    }
}
