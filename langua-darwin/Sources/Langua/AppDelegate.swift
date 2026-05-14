import AppKit
import ApplicationServices
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var mouseTracker: MouseTracker?
    private var selectionTracker: SelectionTracker?
    private var bubbleController: BubbleWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        let bubble = BubbleWindowController()
        self.bubbleController = bubble

        let tracker    = MouseTracker()
        let selTracker = SelectionTracker()
        self.mouseTracker     = tracker
        self.selectionTracker = selTracker

        DispatchQueue.global(qos: .userInitiated).async {
            let engine = PinyinEngine.shared

            DispatchQueue.main.async {

                // ── Hover：鼠标悬停（低优先级）
                tracker.onHover = { text, point, elementFrame in
                    let chars = engine.annotate(text)
                    guard !chars.isEmpty else { return }
                    bubble.show(chars: chars, near: point, elementFrame: elementFrame)
                }
                tracker.onLeave = {
                    bubble.hide()
                }

                // ── Selection：划词（高优先级）
                selTracker.onSelection = { text, point, frame in
                    let chars = engine.annotate(text)
                    guard !chars.isEmpty else { return }
                    bubble.showForSelection(chars: chars, near: point, elementFrame: frame)
                }
                selTracker.onClear = {
                    bubble.clearSelection()
                }

                // ── 悬停开关
                AppState.shared.$enabled
                    .receive(on: RunLoop.main)
                    .sink { enabled in
                        if enabled { tracker.start() } else { tracker.stop() }
                    }
                    .store(in: &AppState.shared.cancellables)

                // ── 划词开关（需同时满足总开关；用 combineLatest 实例方法更可靠）
                AppState.shared.$enabled
                    .combineLatest(AppState.shared.$selectionEnabled)
                    .receive(on: RunLoop.main)
                    .sink { enabled, selEnabled in
                        if enabled && selEnabled { selTracker.start() } else { selTracker.stop() }
                    }
                    .store(in: &AppState.shared.cancellables)

                if AppState.shared.enabled { tracker.start() }
                if AppState.shared.enabled && AppState.shared.selectionEnabled { selTracker.start() }

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
            // 与浏览器插件统一：白色圆底镂空"文"，直接加载 PNG
            if let url = Bundle.main.url(forResource: "toolbar-icon32", withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                img.size = NSSize(width: 18, height: 18)
                btn.image = img
            } else {
                btn.title = "文"
            }
            btn.action = #selector(togglePopover(_:))
            btn.target = self
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 220, height: 310)   // 多一个 Toggle 高度
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
