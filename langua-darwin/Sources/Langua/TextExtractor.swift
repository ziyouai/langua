import AppKit
import ApplicationServices
import Vision
import CoreGraphics

/// 文字提取策略（三级）：
///   1. 直接 AX：光标命中已知内容节点 → 直接返回（原生 App 快速路径）
///   2. AX + OCR 混合：
///      a. 遍历 AX 树收集光标附近所有文字段
///      b. OCR 截图识别光标处大致文字（可能有识别错误）
///      c. 用 OCR 结果在 AX 文字段里做模糊匹配，返回 AX 精确文字
///   3. 纯 OCR 兜底（无 AX 可用时）
///   浏览器始终跳过（由浏览器插件处理）
final class TextExtractor {

    private let maxChars = 200

    // ── AX 角色分类 ──────────────────────────────────────────────────────────

    /// 命中 → 立即放弃（光标在 UI 控件上）
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
        "AXLink",
        "AXColumn", "AXRow",
    ]

    /// 命中 → 直接返回完整文字（快速路径）
    private let contentRoles: Set<String> = [
        "AXStaticText", "AXTextField", "AXTextArea",
        "AXHeading", "AXParagraph",
    ]

    /// 遍历时跳过（容器节点，不直接含文字）
    private let containerSkipRoles: Set<String> = [
        "AXWindow", "AXApplication", "AXSheet", "AXDrawer",
    ]

    // ── 浏览器 bundle ID ──────────────────────────────────────────────────────

    private let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "org.mozilla.firefox",
        "org.mozilla.nightly",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Dev",
        "com.brave.Browser",
        "com.brave.Browser.nightly",
        "company.thebrowser.Browser",   // Arc
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
    ]

    // MARK: - Public

    func getText(at appKitPoint: CGPoint) -> String? {
        guard AXIsProcessTrustedWithOptions(nil) else { return nil }
        if isBrowserAtPoint(appKitPoint) { return nil }

        // ── 快速路径：直接 AX ─────────────────────────────────────────────
        if let text = getTextViaAX(at: appKitPoint) { return text }

        // ── 混合路径：AX 树 + OCR 模糊匹配 ──────────────────────────────
        let axCandidates = collectAXCandidates(near: appKitPoint)
        let ocrText      = getTextViaOCR(at: appKitPoint)

        if !axCandidates.isEmpty, let ocr = ocrText {
            if let matched = fuzzyMatch(ocr: ocr, candidates: axCandidates) {
                return matched
            }
        }

        return ocrText     // 纯 OCR 兜底
    }

    // MARK: - 浏览器检测

    private func isBrowserAtPoint(_ appKitPoint: CGPoint) -> Bool {
        let axPoint = flip(appKitPoint)
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            system, Float(axPoint.x), Float(axPoint.y), &element
        ) == .success, let el = element else { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(el, &pid) == .success, pid > 0 else { return false }
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        return browserBundleIDs.contains(bundleID)
    }

    // MARK: - AX 快速路径

    private func getTextViaAX(at appKitPoint: CGPoint) -> String? {
        let axPoint = flip(appKitPoint)
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            system, Float(axPoint.x), Float(axPoint.y), &element
        ) == .success, let el = element else { return nil }

        var node: AXUIElement = el
        for _ in 0..<10 {
            let role = strAttr(node, kAXRoleAttribute) ?? ""
            if skipRoles.contains(role) { return nil }
            if contentRoles.contains(role) {
                if let text = strAttr(node, kAXValueAttribute), containsCJK(text) {
                    return trim(text)
                }
            }
            guard let p = parent(of: node) else { break }
            node = p
        }
        return nil
    }

    // MARK: - AX 树遍历：收集光标附近所有文字段

    private func collectAXCandidates(near appKitPoint: CGPoint) -> [String] {
        let axPoint = flip(appKitPoint)
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            system, Float(axPoint.x), Float(axPoint.y), &element
        ) == .success, let el = element else { return [] }

        // 向上找合适的容器（ScrollArea / WebArea / Window 为止）
        var container: AXUIElement = el
        for _ in 0..<8 {
            let role = strAttr(container, kAXRoleAttribute) ?? ""
            if role == "AXScrollArea" || role == "AXWebArea"
               || role == "AXWindow"  || role == "AXApplication" { break }
            guard let p = parent(of: container) else { break }
            container = p
        }

        // 从容器向下遍历，收集垂直距离 ≤ 200pt 的文字段
        var results: [String] = []
        collectTextNodes(from: container, cursorY: axPoint.y, into: &results, depth: 0)
        return results
    }

    private func collectTextNodes(from el: AXUIElement,
                                  cursorY: CGFloat,
                                  into results: inout [String],
                                  depth: Int) {
        guard depth < 20 else { return }
        let role = strAttr(el, kAXRoleAttribute) ?? ""
        if skipRoles.contains(role) || containerSkipRoles.contains(role) { return }

        // 检查该元素的屏幕位置（CoreGraphics 坐标，原点左上）
        if let frame = axScreenFrame(el) {
            let vertDist = abs(frame.midY - cursorY)
            if vertDist > 250 { return }   // 距离太远，整棵子树跳过

            // 收集有 CJK 内容、长度合理的文字
            for key in [kAXValueAttribute, kAXTitleAttribute] {
                if let text = strAttr(el, key),
                   containsCJK(text),
                   text.count >= 2,
                   text.count <= 500 {
                    results.append(text)
                    break   // 同一节点只取一次
                }
            }
        }

        // 递归子节点
        var childRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &childRef) == .success,
              let children = childRef as? [AXUIElement] else { return }
        for child in children {
            collectTextNodes(from: child, cursorY: cursorY, into: &results, depth: depth + 1)
        }
    }

    /// 取元素在 CoreGraphics 坐标系中的 frame（原点左上）
    private func axScreenFrame(_ el: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let pv = posRef, let sv = sizeRef else { return nil }
        var pos  = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(pv as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sv as! AXValue, .cgSize, &size)
        guard size.width > 0, size.height > 0 else { return nil }
        return CGRect(origin: pos, size: size)
    }

    // MARK: - OCR（定位用，不作为最终输出）

    private func getTextViaOCR(at appKitPoint: CGPoint) -> String? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        let axPoint = flip(appKitPoint)

        let captureW: CGFloat = 480
        let captureH: CGFloat = 90
        let originX = max(0, axPoint.x - captureW / 2)
        let originY = max(0, axPoint.y - captureH / 2)
        let captureRect = CGRect(x: originX, y: originY, width: captureW, height: captureH)

        guard let cgImage = CGWindowListCreateImage(
            captureRect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution
        ) else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        guard let observations = request.results, !observations.isEmpty else { return nil }

        let normX = (axPoint.x - originX) / captureW
        let normY = 1.0 - (axPoint.y - originY) / captureH

        var best: (score: CGFloat, text: String)? = nil
        for obs in observations {
            guard obs.confidence > 0.15,
                  let text = obs.topCandidates(1).first?.string,
                  containsCJK(text) else { continue }
            let box = obs.boundingBox
            guard normY >= box.minY && normY <= box.maxY else { continue }
            let inBox = box.contains(CGPoint(x: normX, y: normY))
            let dx    = box.midX - normX
            let score: CGFloat = inBox ? 0 : dx * dx
            if best == nil || score < best!.score { best = (score, text) }
        }
        return best?.text
    }

    // MARK: - 模糊匹配：用 OCR 结果在 AX 候选段里找最佳匹配

    /// 返回与 OCR 文字 CJK 字符重叠度最高的 AX 候选段（阈值 0.55）
    private func fuzzyMatch(ocr: String, candidates: [String]) -> String? {
        // 提取 OCR 中的 CJK 字符集合（去重）
        let ocrChars = Set(ocr.unicodeScalars.filter { isCJKScalar($0) }.map { $0.value })
        guard ocrChars.count >= 2 else { return nil }

        var bestScore: Double = 0.55   // 最低阈值：55% 重叠
        var bestText: String? = nil

        for candidate in candidates {
            let candChars = Set(candidate.unicodeScalars.filter { isCJKScalar($0) }.map { $0.value })
            let common = ocrChars.intersection(candChars).count
            let score  = Double(common) / Double(ocrChars.count)
            if score > bestScore {
                bestScore = score
                bestText  = candidate
            }
        }
        return bestText.map { trim($0) }
    }

    // MARK: - AX helpers

    private func strAttr(_ el: AXUIElement, _ key: String) -> String? {
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, key as CFString, &val) == .success else { return nil }
        return val as? String
    }

    private func parent(of el: AXUIElement) -> AXUIElement? {
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &val) == .success,
              CFGetTypeID(val!) == AXUIElementGetTypeID() else { return nil }
        return (val as! AXUIElement)
    }

    // MARK: - Coordinate & text helpers

    private func flip(_ pt: CGPoint) -> CGPoint {
        let h = NSScreen.screens.first?.frame.height ?? 900
        return CGPoint(x: pt.x, y: h - pt.y)
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

    private func trim(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > maxChars else { return t }
        let cutIdx = t.index(t.startIndex, offsetBy: maxChars)
        let head = String(t[..<cutIdx])
        let sentenceEnds: Set<Character> = ["。", "！", "？", "…", ".", "!", "?", "\n"]
        if let lastEnd = head.lastIndex(where: { sentenceEnds.contains($0) }) {
            return String(head[...lastEnd])
        }
        return head + "…"
    }
}
