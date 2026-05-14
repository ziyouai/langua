import AppKit
import ApplicationServices
import Vision
import CoreGraphics

/// 文字提取策略：
///   1. AX 命中测试 → 向上找最近的内容容器（WebArea / 文本节点 / 段落组）
///   2. 若命中路径无内容 → 从进程根节点向下找 AXWebArea（覆盖微信/Electron 嵌入浏览器）
///   3. 纯 OCR 兜底（AX 完全空时）
///
/// 关键设计：
///   • AXWebArea 是目标容器，不是边界 —— 微信公众号文章就在 WebArea 里
///   • 对进程级 AX 根节点做深度优先搜索，影刀等 RPA 工具的做法
///   • 用户偏好整段 → maxChars 500，宽松裁剪
final class TextExtractor {

    // MARK: - 配置

    private let maxChars  = 500
    private let maxWalkUp = 12

    // MARK: - AX 角色

    private let skipRoles: Set<String> = [
        "AXButton", "AXMenuButton",
        "AXMenuItem", "AXMenuBarItem", "AXMenuBar", "AXMenu",
        "AXTab", "AXTabGroup",
        "AXCheckBox", "AXRadioButton",
        "AXSlider", "AXValueIndicator",
        "AXPopUpButton", "AXComboBox",
        "AXToolbar", "AXToolbarButton",
        "AXSplitter", "AXSplitGroup",
        "AXScrollBar", "AXHandle",
        "AXLink", "AXColumn", "AXRow", "AXImage",
    ]

    private let textLeafRoles: Set<String> = [
        "AXStaticText", "AXTextField", "AXTextArea",
        "AXHeading", "AXParagraph",
    ]

    /// 硬边界：向上走到这些角色就停，但 AXScrollArea 不在内（它里面可能有 WebArea）
    private let hardBoundary: Set<String> = [
        "AXApplication", "AXWindow", "AXSheet", "AXDrawer",
    ]

    // MARK: - 浏览器（完全跳过，由插件处理）

    private let browserBundleIDs: Set<String> = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "com.google.Chrome", "com.google.Chrome.canary",
        "org.mozilla.firefox", "org.mozilla.nightly",
        "com.microsoft.edgemac", "com.microsoft.edgemac.Dev",
        "com.brave.Browser", "com.brave.Browser.nightly",
        "company.thebrowser.Browser",  // Arc
        "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
    ]

    // MARK: - 缓存

    private var cachedElement: AXUIElement?
    private var cachedText: String?
    /// 缓存时的光标位置：元素相同但光标跨段落移动时，也要重新提取
    private var cachedPoint: CGPoint = .zero

    /// 最近一次成功提取文字的元素 frame（AppKit 坐标，供气泡定位使用）
    private(set) var lastElementFrame: CGRect? = nil

    // MARK: - Public

    func getText(at appKitPoint: CGPoint) -> String? {
        guard AXIsProcessTrustedWithOptions(nil) else { return nil }

        let axPoint = flip(appKitPoint)
        let system  = AXUIElementCreateSystemWide()

        // ── 1. 命中测试（全程只做一次）
        var rawEl: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            system, Float(axPoint.x), Float(axPoint.y), &rawEl
        ) == .success, let el = rawEl else { return nil }

        // ── 2. 浏览器检测
        var pid: pid_t = 0
        guard AXUIElementGetPid(el, &pid) == .success, pid > 0 else { return nil }
        let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        if browserBundleIDs.contains(bundle) { return nil }

        // ── 3. UI 控件检测
        let hitRole = axRole(el)
        if skipRoles.contains(hitRole) { return nil }

        // ── 4. 缓存命中：AX 元素相同 AND 光标未跨段落移动（距离 < 10pt）
        let dx = appKitPoint.x - cachedPoint.x
        let dy = appKitPoint.y - cachedPoint.y
        if let cached = cachedElement, CFEqual(cached, el), let text = cachedText,
           dx * dx + dy * dy < 100 {
            return text
        }

        // ── 5. 记录命中元素 frame（转换为 AppKit 坐标供气泡定位）
        lastElementFrame = axScreenFrame(el).map { axFrameToAppKit($0) }

        // ── 6. AX 主路径（纯 AX，不做 OCR 兜底）
        let result = extractViaAX(el: el, hitRole: hitRole, pid: pid, axPoint: axPoint)

        cachedElement = result != nil ? el : nil
        cachedText    = result
        cachedPoint   = result != nil ? appKitPoint : .zero
        if result == nil { lastElementFrame = nil }
        return result
    }

    // MARK: - AX 主路径

    private func extractViaAX(el: AXUIElement, hitRole: String,
                               pid: pid_t, axPoint: CGPoint) -> String? {

        // 策略 A：命中元素自身是文本叶子
        if textLeafRoles.contains(hitRole),
           let text = richText(el, isLeaf: true), containsCJK(text) {
            // 向上一层：收集父容器内的所有兄弟文字，合并 inline 粗体/颜色等独立节点
            // （HTML <strong>/<em>/<span> 在 AX 树里是独立 AXStaticText，是兄弟而非子节点）
            if let parent = axParent(el) {
                let parentRole = axRole(parent)
                if !hardBoundary.contains(parentRole) && parentRole != "AXWebArea" {
                    let combined = collectAllDescendantText(from: parent, depth: 0, maxDepth: 3)
                    let cjk = cjkCount(combined)
                    // 合并内容更完整且不超过整篇幅 → 用合并版
                    if cjk > cjkCount(text) && cjk <= 300 {
                        log("[A+] \(combined.prefix(80))")
                        return trim(combined)
                    }
                }
            }
            log("[A] \(hitRole) \(text.prefix(60))")
            return trim(text)
        }

        log("[hit] role=\(hitRole)")

        // 策略 B：向上找 WebArea 或文本容器（用光标 Y 坐标做近邻过滤）
        if let text = walkUpForText(from: el, cursorY: axPoint.y) {
            log("[B] \(text.prefix(60))")
            return trim(text)
        }

        // 策略 C：从进程根节点向下找 AXWebArea（覆盖 Electron/微信）
        if let text = findWebAreaText(pid: pid, cursorY: axPoint.y) {
            log("[C] \(text.prefix(80))")
            return trim(text)
        }

        log("[AX-fail]")
        return nil
    }

    // MARK: - 策略 B：向上找内容

    private func walkUpForText(from el: AXUIElement, cursorY: CGFloat) -> String? {
        var node: AXUIElement = el
        for _ in 0..<maxWalkUp {
            guard let p = axParent(node) else { break }
            let role = axRole(p)
            if hardBoundary.contains(role) { break }

            // 遇到 WebArea → 先用光标附近的叶子文字
            if role == "AXWebArea" {
                var parts: [String] = []
                collectNearbyLeafs(from: p, cursorY: cursorY, vertTol: 80,
                                   depth: 0, maxDepth: 10, into: &parts)
                let nearText = parts.joined()
                if cjkCount(nearText) >= 4 { return nearText }
                // fallback: 所有后代文字
                let allText = collectAllDescendantText(from: p, depth: 0, maxDepth: 10)
                if containsCJK(allText) { return allText }
                break
            }

            // 普通容器 → 先尝试光标附近的文字（精确定位）
            var parts: [String] = []
            collectNearbyLeafs(from: p, cursorY: cursorY, vertTol: 100,
                               depth: 0, maxDepth: 6, into: &parts)
            let nearText = parts.joined()
            if cjkCount(nearText) >= 4 { return nearText }

            // 再尝试整个容器的文字（节点本身是内容容器，范围适中）
            let text = collectAllDescendantText(from: p, depth: 0, maxDepth: 4)
            let cjk  = cjkCount(text)
            if cjk >= 4 && cjk <= 200 { return text }

            node = p
        }
        return nil
    }

    // MARK: - 策略 C：从进程根节点找 AXWebArea

    /// 影刀等 RPA 工具的做法：从 AXApplication 根节点深度优先搜索 WebArea，
    /// 找到后收集其中离光标最近的文字段落。
    private func findWebAreaText(pid: pid_t, cursorY: CGFloat) -> String? {
        let appEl = AXUIElementCreateApplication(pid)
        guard let webArea = findWebArea(in: appEl, depth: 0, maxDepth: 15) else {
            log("[C] no WebArea found in pid=\(pid)")
            return nil
        }
        log("[C] found WebArea")

        // 收集 WebArea 中所有叶子文本，用 Y 坐标过滤出光标附近的段落
        var nearParts: [String] = []
        collectNearbyLeafs(from: webArea, cursorY: cursorY, vertTol: 60,
                           depth: 0, maxDepth: 12, into: &nearParts)
        let nearText = nearParts.joined()
        if cjkCount(nearText) >= 4 { return nearText }

        // 若没有位置信息（某些 Chromium 版本），收集全部文字，trim 到 maxChars
        let allText = collectAllDescendantText(from: webArea, depth: 0, maxDepth: 12)
        return cjkCount(allText) >= 4 ? allText : nil
    }

    /// 深度优先搜索第一个 AXWebArea（使用 axChildren 覆盖多种属性键）
    private func findWebArea(in el: AXUIElement, depth: Int, maxDepth: Int) -> AXUIElement? {
        guard depth < maxDepth else { return nil }
        if axRole(el) == "AXWebArea" { return el }
        for child in axChildren(el) {
            if let found = findWebArea(in: child, depth: depth + 1, maxDepth: maxDepth) {
                return found
            }
        }
        return nil
    }

    // MARK: - 文字收集

    /// 递归收集所有后代的文字（叶子节点优先）
    /// 关键：只在叶子节点（无子节点，或角色属于 textLeafRoles）读取 text/title，
    /// 避免容器节点的 kAXTitleAttribute（文章标题）被当成内容返回。
    private func collectAllDescendantText(from el: AXUIElement,
                                          depth: Int, maxDepth: Int) -> String {
        guard depth < maxDepth else { return "" }
        let role = axRole(el)
        if skipRoles.contains(role) { return "" }

        let children = axChildren(el)
        // 叶子节点：读取自身文字
        let isLeaf = children.isEmpty || textLeafRoles.contains(role)
        if isLeaf {
            return richText(el, isLeaf: true) ?? ""
        }
        // 容器节点：只递归子节点，忽略自身 title/value（避免把文章标题误当内容）
        return children
            .map { collectAllDescendantText(from: $0, depth: depth + 1, maxDepth: maxDepth) }
            .filter { !$0.isEmpty }
            .joined()
    }

    /// 尝试多个属性键获取子节点，覆盖 WKWebView/Electron 不同实现
    private func axChildren(_ el: AXUIElement) -> [AXUIElement] {
        for key in [kAXChildrenAttribute, "AXVisibleChildren", "AXContents"] {
            var ref: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, key as CFString, &ref) == .success,
               let arr = ref as? [AXUIElement], !arr.isEmpty {
                return arr
            }
        }
        return []
    }

    /// 收集光标 Y ± vertTol 范围内的叶子文本（有位置信息时精确过滤）
    /// 同样只在叶子节点读取文字，容器节点仅做剪枝判断。
    private func collectNearbyLeafs(from el: AXUIElement,
                                    cursorY: CGFloat, vertTol: CGFloat,
                                    depth: Int, maxDepth: Int,
                                    into parts: inout [String]) {
        guard depth < maxDepth else { return }
        let role = axRole(el)
        if skipRoles.contains(role) { return }

        let children = axChildren(el)
        let isLeaf = children.isEmpty || textLeafRoles.contains(role)

        if isLeaf {
            guard let text = richText(el, isLeaf: true), !text.isEmpty else { return }
            if let frame = axScreenFrame(el) {
                if abs(frame.midY - cursorY) <= vertTol { parts.append(text) }
            } else {
                parts.append(text)  // 无位置信息 → 全纳入
            }
            return
        }

        // 容器：若整体 frame 距离太远则剪枝
        if let frame = axScreenFrame(el), abs(frame.midY - cursorY) > 200 { return }

        for child in children {
            collectNearbyLeafs(from: child, cursorY: cursorY, vertTol: vertTol,
                               depth: depth + 1, maxDepth: maxDepth, into: &parts)
        }
    }

    // MARK: - OCR 兜底

    private func extractViaOCR(at appKitPoint: CGPoint) -> String? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        let axPoint = flip(appKitPoint)

        let w: CGFloat = 520, h: CGFloat = 100
        let rect = CGRect(x: max(0, axPoint.x - w/2), y: max(0, axPoint.y - h/2),
                          width: w, height: h)
        guard let img = CGWindowListCreateImage(rect, .optionOnScreenOnly,
                                               kCGNullWindowID, .bestResolution) else { return nil }

        let req = VNRecognizeTextRequest()
        req.recognitionLanguages  = ["zh-Hans", "zh-Hant", "en-US"]
        req.recognitionLevel      = .accurate
        req.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: img, options: [:]).perform([req])

        guard let obs = req.results, !obs.isEmpty else { return nil }
        let nx = (axPoint.x - rect.minX) / w
        let ny = 1.0 - (axPoint.y - rect.minY) / h

        return obs
            .filter { $0.confidence > 0.15 }
            .compactMap { o -> (CGFloat, String)? in
                guard let t = o.topCandidates(1).first?.string, containsCJK(t) else { return nil }
                let b = o.boundingBox
                guard ny >= b.minY - 0.05 && ny <= b.maxY + 0.05 else { return nil }
                let score: CGFloat = b.contains(CGPoint(x: nx, y: ny)) ? 0 : abs(b.midX - nx)
                return (score, t)
            }
            .min(by: { $0.0 < $1.0 })
            .map { trim($0.1) }
    }

    // MARK: - OCR 后处理

    private func fixOCR(_ text: String) -> String {
        var s = text.replacingOccurrences(of: "一一", with: "——")
        if let re = try? NSRegularExpression(
            pattern: "(?<![\\u4E00-\\u9FFF])一(?![\\u4E00-\\u9FFF])"
        ) {
            s = re.stringByReplacingMatches(in: s,
                range: NSRange(s.startIndex..., in: s), withTemplate: "—")
        }
        return s
    }

    // MARK: - AX 工具

    private func axRole(_ el: AXUIElement) -> String {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &v) == .success
        else { return "" }
        return (v as? String) ?? ""
    }

    /// isLeaf=true 时同时尝试 kAXValueAttribute 和 kAXTitleAttribute；
    /// isLeaf=false（容器节点）只读 kAXValueAttribute，避免把文章标题误当段落内容。
    private func richText(_ el: AXUIElement, isLeaf: Bool = false) -> String? {
        let keys: [String] = isLeaf
            ? [kAXValueAttribute, kAXTitleAttribute]
            : [kAXValueAttribute]
        for key in keys {
            var v: CFTypeRef?
            if AXUIElementCopyAttributeValue(el, key as CFString, &v) == .success,
               let s = v as? String,
               !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return s
            }
        }
        return nil
    }

    private func axParent(_ el: AXUIElement) -> AXUIElement? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &v) == .success,
              let raw = v, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)
    }

    private func axScreenFrame(_ el: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let pv = posRef, let sv = sizeRef else { return nil }
        var pos = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(pv as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sv as! AXValue, .cgSize, &size)
        guard size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: pos, size: size)
    }

    // MARK: - 坐标 & 文字工具

    private func flip(_ pt: CGPoint) -> CGPoint {
        CGPoint(x: pt.x, y: (NSScreen.screens.first?.frame.height ?? 900) - pt.y)
    }

    /// AX 坐标（y 从屏幕顶部向下）→ AppKit 坐标（y 从屏幕底部向上）
    private func axFrameToAppKit(_ f: CGRect) -> CGRect {
        let screenH = NSScreen.screens.first?.frame.height ?? 900
        return CGRect(x: f.minX, y: screenH - f.maxY, width: f.width, height: f.height)
    }

    private func isCJKScalar(_ s: Unicode.Scalar) -> Bool {
        (s.value >= 0x4E00 && s.value <= 0x9FFF) ||
        (s.value >= 0x3400 && s.value <= 0x4DBF) ||
        (s.value >= 0xF900 && s.value <= 0xFAFF) ||
        (s.value >= 0x2E80 && s.value <= 0x2FFF)
    }

    private func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { isCJKScalar($0) }
    }

    private func cjkCount(_ text: String) -> Int {
        text.unicodeScalars.filter { isCJKScalar($0) }.count
    }

    private func trim(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > maxChars else { return t }
        let cut  = t.index(t.startIndex, offsetBy: maxChars)
        let head = String(t[..<cut])
        let ends: Set<Character> = ["。","！","？","…",".","\n","!","?"]
        if let last = head.lastIndex(where: { ends.contains($0) }) {
            return String(head[...last])
        }
        return head + "…"
    }

    // MARK: - Debug

    private func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        let url  = URL(fileURLWithPath: "/tmp/langua-debug.log")
        guard let data = line.data(using: .utf8) else { return }
        if let fh = try? FileHandle(forWritingTo: url) {
            fh.seekToEndOfFile(); fh.write(data); try? fh.close()
        } else {
            try? data.write(to: url)
        }
    }
}
