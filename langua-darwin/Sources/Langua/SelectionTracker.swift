import AppKit
import ApplicationServices

/// 划词拼音：监听文字选区变化（鼠标划选 / Shift+方向键 / Cmd+A），
/// 提取选中汉字并触发气泡。
///
/// 行为：
///   • 选区气泡"粘住"——鼠标移动不消失
///   • 鼠标按下（新一次点击）时清除气泡
///   • 适用于所有应用（包含浏览器，弥补插件没有划词气泡的场景）
///
/// 所有回调均在主线程触发。
final class SelectionTracker {

    /// (选中文字, 选区中点, 选区 AppKit frame)；主线程回调
    var onSelection: ((String, CGPoint, CGRect?) -> Void)?
    /// 鼠标按下或选区为空时清除气泡；主线程回调
    var onClear: (() -> Void)?

    private var mouseUpMonitor:   Any?
    private var mouseDownMonitor: Any?
    private var keyUpMonitor:     Any?

    func start() {
        guard mouseUpMonitor == nil else { return }

        // ── 鼠标松开 → 检查选区
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.scheduleCheck()
        }

        // ── 鼠标按下 → 清除旧选区气泡
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            DispatchQueue.main.async { self?.onClear?() }
        }

        // ── 键盘选词：Shift+方向键 / Shift+Home/End / Cmd+A
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            let flags = event.modifierFlags
            let isShiftArrow = flags.contains(.shift) &&
                [123, 124, 125, 126, 115, 119].contains(Int(event.keyCode))  // ←→↑↓ Home End
            let isCmdA = flags.contains(.command) && event.keyCode == 0      // Cmd+A
            if isShiftArrow || isCmdA {
                self?.scheduleCheck()
            }
        }
    }

    func stop() {
        [mouseUpMonitor, mouseDownMonitor, keyUpMonitor]
            .compactMap { $0 }
            .forEach { NSEvent.removeMonitor($0) }
        mouseUpMonitor   = nil
        mouseDownMonitor = nil
        keyUpMonitor     = nil
        DispatchQueue.main.async { self.onClear?() }
    }

    // MARK: - Private

    private func scheduleCheck() {
        // 稍作延迟，让目标 App 完成选区更新
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.checkSelection()
        }
    }

    private func checkSelection() {
        guard AXIsProcessTrustedWithOptions(nil) else { return }

        // 取当前焦点元素
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            system, kAXFocusedUIElementAttribute as CFString, &focusedRef
        ) == .success,
        let raw = focusedRef, CFGetTypeID(raw) == AXUIElementGetTypeID() else {
            DispatchQueue.main.async { self.onClear?() }
            return
        }
        let el = raw as! AXUIElement

        // 读选中文字
        var textRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            el, kAXSelectedTextAttribute as CFString, &textRef
        ) == .success,
        let text = textRef as? String,
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        hasCJK(text) else {
            DispatchQueue.main.async { self.onClear?() }
            return
        }

        let (point, frame) = selectionBounds(el: el)
        DispatchQueue.main.async {
            self.onSelection?(text, point, frame)
        }
    }

    // MARK: - 选区坐标

    private func selectionBounds(el: AXUIElement) -> (CGPoint, CGRect?) {
        // 1. 取选区 CFRange
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            el, kAXSelectedTextRangeAttribute as CFString, &rangeRef
        ) == .success, let rv = rangeRef else {
            return (NSEvent.mouseLocation, nil)
        }

        // 2. 包装成 AXValue<CFRange>
        var cfRange = CFRange()
        guard AXValueGetValue(rv as! AXValue, .cfRange, &cfRange),
              let rangeVal = AXValueCreate(.cfRange, &cfRange) else {
            return (NSEvent.mouseLocation, nil)
        }

        // 3. 查询选区屏幕矩形（AX 坐标：y 从屏幕顶部向下）
        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            el,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeVal,
            &boundsRef
        ) == .success, let br = boundsRef else {
            return (NSEvent.mouseLocation, nil)
        }

        var axRect = CGRect.zero
        guard AXValueGetValue(br as! AXValue, .cgRect, &axRect),
              axRect.width > 0, axRect.height > 0 else {
            return (NSEvent.mouseLocation, nil)
        }

        // 4. AX → AppKit 坐标（y 从屏幕底部向上）
        let screenH = NSScreen.screens.first?.frame.height ?? 900
        let appKitRect = CGRect(
            x: axRect.minX,
            y: screenH - axRect.maxY,
            width: axRect.width,
            height: axRect.height
        )
        let mid = CGPoint(x: appKitRect.midX, y: appKitRect.midY)
        return (mid, appKitRect)
    }

    // MARK: - 工具

    private func hasCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3400 && $0.value <= 0x4DBF) ||
            ($0.value >= 0xF900 && $0.value <= 0xFAFF)
        }
    }
}
