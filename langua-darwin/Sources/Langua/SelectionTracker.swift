import AppKit
import ApplicationServices
import LangObjC

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

    private var mouseDownMonitor: Any?
    private var mouseUpMonitor:   Any?
    private var keyUpMonitor:     Any?
    private var mouseDownPoint: CGPoint = .zero
    private let checkQueue = DispatchQueue(label: "com.langua.selectionCheck", qos: .userInteractive)
    private var pendingWork: DispatchWorkItem?

    func start() {
        guard mouseUpMonitor == nil else { return }

        // ── 鼠标按下 → 记录位置，用于判断是否是拖选
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.mouseDownPoint = NSEvent.mouseLocation
        }

        // ── 鼠标松开 → 检查是否拖选（>5px 才触发剪贴板策略）
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self = self else { return }
            let cur = NSEvent.mouseLocation
            let dx = cur.x - self.mouseDownPoint.x
            let dy = cur.y - self.mouseDownPoint.y
            let isDrag = (dx * dx + dy * dy) > 25
            self.scheduleCheck(likelyHasSelection: isDrag)
        }

        // ── 键盘选词：Shift+方向键 / Shift+Home/End / Cmd+A
        keyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            let flags = event.modifierFlags
            let isShiftArrow = flags.contains(.shift) &&
                [123, 124, 125, 126, 115, 119].contains(Int(event.keyCode))
            let isCmdA = flags.contains(.command) && event.keyCode == 0
            if isShiftArrow || isCmdA {
                self?.scheduleCheck(likelyHasSelection: true)
            }
        }
    }

    func stop() {
        if let m = mouseDownMonitor { NSEvent.removeMonitor(m); mouseDownMonitor = nil }
        if let m = mouseUpMonitor   { NSEvent.removeMonitor(m); mouseUpMonitor   = nil }
        if let m = keyUpMonitor     { NSEvent.removeMonitor(m); keyUpMonitor     = nil }
        DispatchQueue.main.async { self.onClear?() }
    }

    // MARK: - Private

    private func scheduleCheck(likelyHasSelection: Bool = false) {
        pendingWork?.cancel()
        let tryClipboard = likelyHasSelection
        let work = DispatchWorkItem { [weak self] in
            self?.checkSelection(tryClipboard: tryClipboard)
        }
        pendingWork = work
        checkQueue.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    private func checkSelection(tryClipboard: Bool) {
        // Layer 1：局部捕获所有 ObjC 异常，静默失败而不崩溃
        objcTryCatch({
            self._checkSelection(tryClipboard: tryClipboard)
        }, { e in
            NSLog("[Langua] ObjC exception caught in checkSelection: %@ — %@", e.name.rawValue, e.reason ?? "")
        })
    }

    private func _checkSelection(tryClipboard: Bool) {
        guard AXIsProcessTrustedWithOptions(nil) else { return }

        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let axOk = AXUIElementCopyAttributeValue(
            system, kAXFocusedUIElementAttribute as CFString, &focusedRef
        ) == .success

        // 有有效 AX element → 先走 AX 策略
        if axOk, let raw = focusedRef, CFGetTypeID(raw) == AXUIElementGetTypeID() {
            let el = raw as! AXUIElement
            if let (text, foundEl) = selectedText(from: el, tryClipboard: tryClipboard) {
                let (point, frame) = selectionBounds(el: foundEl)
                DispatchQueue.main.async { self.onSelection?(text, point, frame) }
                return
            }
            // AX 可达但无选中文字 → 清除气泡，不再尝试剪贴板（避免误触 Cmd+C）
            DispatchQueue.main.async { self.onClear?() }
            return
        }

        // AX 完全不可达（微信等自定义视图）→ 仅在明确有选区时才走剪贴板兜底
        if tryClipboard, let text = textViaClipboard(el: nil), hasCJK(text) {
            let point = NSEvent.mouseLocation
            DispatchQueue.main.async { self.onSelection?(text, point, nil) }
        } else {
            DispatchQueue.main.async { self.onClear?() }
        }
    }

    /// 从 el 本身或其所在窗口的 AX 树中找到有选中文字的元素
    private func selectedText(from el: AXUIElement, tryClipboard: Bool) -> (String, AXUIElement)? {
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
        if let result = findSelectedText(in: node, depth: 0, maxDepth: 12) { return result }

        // 策略 3：仅在确认有选区时才模拟 Cmd+C（避免在普通单击时误注入按键）
        if tryClipboard, let text = textViaClipboard(el: el as AXUIElement?), hasCJK(text) { return (text, el) }

        return nil
    }

    /// 模拟 Cmd+C，短暂读取剪贴板后还原原内容
    ///
    /// 根本原因：NSPasteboard.string(forType:) 在主线程执行时，RunLoop 同时处理
    /// 粘贴板服务器的变更通知，触发 _updateTypeCacheIfNeeded 重入，内部集合边遍历
    /// 边被修改，导致 __NSFastEnumerationMutationHandler 崩溃。这是 AppKit bug。
    ///
    /// 修法：完全不在进程内读写剪贴板字符串内容，改用 pbpaste/pbcopy 子进程，
    /// 彻底隔离 NSPasteboard 内部状态。只保留 changeCount（整数读取，不触发缓存更新）。
    private func textViaClipboard(el: AXUIElement?) -> String? {
        // ── 1. 子进程读取初始内容 + 主线程读 changeCount ────────────────
        let oldString = pbpaste()
        var oldCount  = 0
        DispatchQueue.main.sync { oldCount = NSPasteboard.general.changeCount }

        // ── 2. 先尝试 AX copy action ────────────────────────────────────
        if let el = el {
            _ = AXUIElementPerformAction(el, "AXCopy" as CFString)
        }

        // ── 3. CGEvent 模拟 Cmd+C ────────────────────────────────────────
        var countAfterAX = 0
        DispatchQueue.main.sync { countAfterAX = NSPasteboard.general.changeCount }
        if countAfterAX == oldCount {
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            let src = CGEventSource(stateID: .hidSystemState)
            if let dn = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true) {
                dn.flags = .maskCommand
                if pid > 0 { dn.postToPid(pid) } else { dn.post(tap: .cgAnnotatedSessionEventTap) }
            }
            Thread.sleep(forTimeInterval: 0.06)
            if let up = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false) {
                up.flags = .maskCommand
                if pid > 0 { up.postToPid(pid) } else { up.post(tap: .cgAnnotatedSessionEventTap) }
            }
        }

        // ── 4. 轮询 changeCount（只读整数，不触发缓存更新路径）──────────
        var waited   = 0
        var newCount = oldCount
        while newCount == oldCount && waited < 80 {
            Thread.sleep(forTimeInterval: 0.01)
            waited += 1
            DispatchQueue.main.sync { newCount = NSPasteboard.general.changeCount }
        }

        guard newCount != oldCount else { return nil }

        // ── 5. 子进程读取结果（完全绕过进程内 NSPasteboard）────────────
        let text = pbpaste()
        guard let text, !text.isEmpty, hasCJK(text) else { return nil }

        // ── 6. 延迟还原（pbcopy 子进程写回，彻底隔离）─────────────────
        let captured = oldString
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            if let old = captured { self?.pbcopy(old) }
        }

        return text
    }

    // pbpaste 子进程：不触及进程内 NSPasteboard，彻底避免 re-entrant 崩溃
    private func pbpaste() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pbpaste")
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let s = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        return s.flatMap { $0.isEmpty ? nil : $0 }
    }

    // pbcopy 子进程：安全写回剪贴板
    private func pbcopy(_ text: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
        let pipe = Pipe()
        proc.standardInput = pipe
        try? proc.run()
        pipe.fileHandleForWriting.write(Data(text.utf8))
        pipe.fileHandleForWriting.closeFile()
        proc.waitUntilExit()
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
