import AppKit
import ApplicationServices

/// 划词拼音：监听文字选区变化（鼠标划选 / Shift+方向键 / Cmd+A），
/// 提取选中汉字并触发气泡。
///
/// 设计原则：
///   • 统一由 mouseUp 检测：有选区 → onSelection；无选区 → onClear
///   • 不在 mouseDown 立即清除——那会产生与 showForSelection 的主线程竞态
///     （onClear async 排到 showForSelection 之后执行，气泡一闪即灭）
///   • 气泡"粘住"：鼠标移动不消失，下次 mouseUp（无选区）才清除
///
/// 所有回调均在主线程触发。
final class SelectionTracker {

    /// (选中文字, 选区中点, 选区 AppKit frame)；主线程回调
    var onSelection: ((String, CGPoint, CGRect?) -> Void)?
    /// 选区为空（单击取消选区）时清除气泡；主线程回调
    var onClear: (() -> Void)?

    private var mouseUpMonitor: Any?
    private var keyUpMonitor:   Any?

    func start() {
        guard mouseUpMonitor == nil else { return }

        // ── 鼠标松开 → 检查选区（有则显示，无则清除）
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.scheduleCheck()
        }

        // ── 键盘选词：Shift+方向键 / Shift+Home/End / Cmd+A
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            let flags = event.modifierFlags
            let isShiftArrow = flags.contains(.shift) &&
                [123, 124, 125, 126, 115, 119].contains(Int(event.keyCode))
            let isCmdA = flags.contains(.command) && event.keyCode == 0
            if isShiftArrow || isCmdA {
                self?.scheduleCheck()
            }
        }
    }

    func stop() {
        if let m = mouseUpMonitor { NSEvent.removeMonitor(m); mouseUpMonitor = nil }
        if let m = keyUpMonitor   { NSEvent.removeMonitor(m); keyUpMonitor   = nil }
        DispatchQueue.main.async { self.onClear?() }
    }

    // MARK: - Private

    private func scheduleCheck() {
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.checkSelection()
        }
    }

    private func checkSelection() {
        guard AXIsProcessTrustedWithOptions(nil) else { return }

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
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            el, kAXSelectedTextRangeAttribute as CFString, &rangeRef
        ) == .success, let rv = rangeRef else {
            return (NSEvent.mouseLocation, nil)
        }

        var cfRange = CFRange()
        guard AXValueGetValue(rv as! AXValue, .cfRange, &cfRange),
              let rangeVal = AXValueCreate(.cfRange, &cfRange) else {
            return (NSEvent.mouseLocation, nil)
        }

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

        let screenH = NSScreen.screens.first?.frame.height ?? 900
        let appKitRect = CGRect(
            x: axRect.minX,
            y: screenH - axRect.maxY,
            width: axRect.width,
            height: axRect.height
        )
        return (CGPoint(x: appKitRect.midX, y: appKitRect.midY), appKitRect)
    }

    private func hasCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3400 && $0.value <= 0x4DBF) ||
            ($0.value >= 0xF900 && $0.value <= 0xFAFF)
        }
    }
}
