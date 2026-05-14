import AppKit
import SwiftUI

/// 悬浮气泡窗口：NSPanel + SwiftUI 内容，跟随鼠标显示，不抢焦点。
final class BubbleWindowController {
    private let panel: NSPanel

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
        // 随 Space 和全屏模式一起移动
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.alphaValue = 0
    }

    // MARK: - Public

    func show(chars: [AnnotatedChar], near appKitPoint: CGPoint) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setContent(chars)
            self.position(near: appKitPoint)
            self.fadeIn()
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.fadeOut()
        }
    }

    // MARK: - Private

    private func setContent(_ chars: [AnnotatedChar]) {
        let view = BubbleView(chars: chars)
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = host
        // 让 SwiftUI 计算合适尺寸
        let fit = host.fittingSize
        panel.setContentSize(NSSize(width: min(fit.width, 800), height: fit.height))
    }

    private func position(near pt: CGPoint) {
        // 气泡默认出现在光标右上方 12pt
        let offset: CGFloat = 12
        var origin = NSPoint(x: pt.x + offset, y: pt.y + offset)

        let size = panel.frame.size
        // 选择含光标的屏幕，避免跨屏错位
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pt) })
            ?? NSScreen.main
        if let sf = screen?.visibleFrame {
            // 右溢 → 靠左显示
            if origin.x + size.width > sf.maxX - 8 {
                origin.x = pt.x - size.width - offset
            }
            // 上溢 → 显示在光标下方
            if origin.y + size.height > sf.maxY - 8 {
                origin.y = pt.y - size.height - offset
            }
            // 下溢 / 左溢 → clamp
            origin.x = max(sf.minX + 8, origin.x)
            origin.y = max(sf.minY + 8, origin.y)
        }
        panel.setFrameOrigin(origin)
    }

    private func fadeIn() {
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.10
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        }
    }
}
