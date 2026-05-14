import AppKit
import ApplicationServices
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var mouseTracker: MouseTracker?
    private var bubbleController: BubbleWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        let bubble = BubbleWindowController()
        self.bubbleController = bubble

        let tracker = MouseTracker()
        self.mouseTracker = tracker

        DispatchQueue.global(qos: .userInitiated).async {
            let engine = PinyinEngine.shared

            DispatchQueue.main.async {
                tracker.onHover = { text, point in
                    let chars = engine.annotate(text)
                    guard !chars.isEmpty else { return }
                    bubble.show(chars: chars, near: point)
                }
                tracker.onLeave = {
                    bubble.hide()
                }

                AppState.shared.$enabled
                    .receive(on: RunLoop.main)
                    .sink { enabled in
                        if enabled { tracker.start() } else { tracker.stop() }
                    }
                    .store(in: &AppState.shared.cancellables)

                if AppState.shared.enabled { tracker.start() }

                // 延迟 2 秒再检查权限，避免 UI 未完全显示时就弹系统对话框
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.checkAccessibility()
                }
            }
        }
    }

    // MARK: - 菜单栏图标

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem?.button {
            // 优先用 SF Symbol，不可用时降级为文字
            if let img = NSImage(systemSymbolName: "text.bubble.fill",
                                 accessibilityDescription: "langua") {
                img.isTemplate = true
                btn.image = img
            } else {
                btn.title = "拼"
            }
            btn.action = #selector(togglePopover(_:))
            btn.target = self
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 220, height: 280)
        pop.behavior = .transient
        pop.animates = false
        pop.contentViewController = NSHostingController(
            rootView: MenuBarContent().environmentObject(AppState.shared)
        )
        self.popover = pop
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        guard let pop = popover, let btn = statusItem?.button else { return }
        if pop.isShown {
            pop.performClose(sender)
        } else {
            pop.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - 辅助功能授权

    private func checkAccessibility() {
        if AXIsProcessTrustedWithOptions(nil) { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
