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
                // onHover 已由 MouseTracker 在主线程回调，可直接操作 UI
                tracker.onHover = { text, point, elementFrame in
                    let chars = engine.annotate(text)
                    guard !chars.isEmpty else { return }
                    bubble.show(chars: chars, near: point, elementFrame: elementFrame)
                }
                tracker.onLeave = {
                    bubble.hide()
                }

                // ── Selection：划词（高优先级）
                // onSelection 已由 SelectionTracker 在主线程回调
                selTracker.onSelection = { text, point, frame in
                    let chars = engine.annotate(text)
                    guard !chars.isEmpty else { return }
                    bubble.showForSelection(chars: chars, near: point, elementFrame: frame)
                }
                selTracker.onClear = {
                    bubble.clearSelection()
                }

                // ── 启用开关
                AppState.shared.$enabled
                    .receive(on: RunLoop.main)
                    .sink { enabled in
                        if enabled {
                            tracker.start()
                            selTracker.start()
                        } else {
                            tracker.stop()
                            selTracker.stop()
                        }
                    }
                    .store(in: &AppState.shared.cancellables)

                if AppState.shared.enabled {
                    tracker.start()
                    selTracker.start()
                }

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
