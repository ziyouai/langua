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

        // 先从 focused element 读，失败则扫 focused window（兼容微信等自定义视图）
        if let (text, foundEl) = selectedText(from: el) {
            let (point, frame) = selectionBounds(el: foundEl)
            DispatchQueue.main.async { self.onSelection?(text, point, frame) }
        } else {
            DispatchQueue.main.async { self.onClear?() }
        }
    }

    /// 从 el 本身或其所在窗口的 AX 树中找到有选中文字的元素
    private func selectedText(from el: AXUIElement) -> (String, AXUIElement)? {
        // 策略 1：直接读 focused element
        if let text = axSelectedText(el), hasCJK(text) { return (text, el) }

        // 策略 2：往上找到 AXWindow，再 DFS 找有选中文字的子元素
        var node: AXUIElement = el
        for _ in 0..<15 {
            if axRole(node) == "AXWindow" { break }
            var p: CFTypeRef?
            guard AXUIElementCopyAttributeValue(node, kAXParentAttribute as CFString, &p) == .success,
                  let pr = p, CFGetTypeID(pr) == AXUIElementGetTypeID() else { break }
            node = pr as! AXUIElement
        }
        return findSelectedText(in: node, depth: 0, maxDepth: 12)
    }

    private func findSelectedText(in el: AXUIElement, depth: Int, maxDepth: Int) -> (String, AXUIElement)? {
        guard depth < maxDepth else { return nil }
        if let text = axSelectedText(el), hasCJK(text) { return (text, el) }
        var childRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childRef) == .success,
              let children = childRef as? [AXUIElement] else { return nil }
        for child in children {
            if let result = findSelectedText(in: child, depth: depth + 1, maxDepth: maxDepth) {
                return result
            }
        }
        return nil
    }

    private func axSelectedText(_ el: AXUIElement) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXSelectedTextAttribute as CFString, &ref) == .success,
              let text = ref as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private func axRole(_ el: AXUIElement) -> String {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &ref) == .success
        else { return "" }
        return (ref as? String) ?? ""
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
