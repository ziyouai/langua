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

    func show(chars: [AnnotatedChar], near appKitPoint: CGPoint, elementFrame: CGRect? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setContent(chars)
            self.position(near: appKitPoint, elementFrame: elementFrame)
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

    private func position(near pt: CGPoint, elementFrame: CGRect? = nil) {
        let size   = panel.frame.size
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pt) }) ?? NSScreen.main
        let sf     = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let gap: CGFloat = 8

        var origin: NSPoint

        if let ef = elementFrame {
            // 有元素 frame：气泡出现在元素正上方，避免遮挡文字；
            // 若上方空间不足（元素靠近屏幕顶部），则改为显示在元素正下方。
            let elemTop = ef.maxY   // AppKit: maxY = 元素上边缘（Y 大 = 屏幕上方）
            let elemBot = ef.minY   // AppKit: minY = 元素下边缘（Y 小 = 屏幕下方）

            let aboveY = elemTop + gap
            if aboveY + size.height <= sf.maxY - 4 {
                // 上方够位置
                origin = NSPoint(x: pt.x - size.width / 2, y: aboveY)
            } else {
                // 上方溢出 → 显示在元素下方
                origin = NSPoint(x: pt.x - size.width / 2, y: elemBot - size.height - gap)
            }
        } else {
            // 无 frame 兜底：光标右上方 12pt（同原来逻辑）
            let offset: CGFloat = 12
            origin = NSPoint(x: pt.x + offset, y: pt.y + offset)
            if origin.y + size.height > sf.maxY - 8 {
                origin.y = pt.y - size.height - offset
            }
        }

        // 左右防溢出
        origin.x = max(sf.minX + 8, min(origin.x, sf.maxX - size.width - 8))
        // 上下防溢出
        origin.y = max(sf.minY + 8, min(origin.y, sf.maxY - size.height - 8))

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
