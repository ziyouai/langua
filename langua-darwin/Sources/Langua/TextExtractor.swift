import AppKit
import ApplicationServices
import Vision
import CoreGraphics

/// 读取光标下的中文文字。
/// 优先用 AX API（快，不需要屏幕录制权限）；
/// AX 读不到时自动切换 OCR（Vision + 屏幕截图，需要屏幕录制权限）。
final class TextExtractor {

    private let maxChars = 120

    // AX 路径只信任这些真正的文字角色，其余容器/控件一律忽略（走 OCR）
    private let textRoles: Set<String> = [
        "AXStaticText", "AXTextField", "AXTextArea",
        "AXHeading", "AXParagraph"
    ]

    func getText(at appKitPoint: CGPoint) -> String? {
        guard AXIsProcessTrustedWithOptions(nil) else { return nil }

        // 优先：AX API（原生 App 精准快速）
        if let text = getTextViaAX(at: appKitPoint) {
            return text
        }

        // 兜底：OCR（对 WKWebView / Electron / 游戏 等任意 App 都可靠）
        return getTextViaOCR(at: appKitPoint)
    }

    // MARK: - AX API 路径

    private func getTextViaAX(at appKitPoint: CGPoint) -> String? {
        let axPoint = flip(appKitPoint)
        let system = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(
            system, Float(axPoint.x), Float(axPoint.y), &element
        ) == .success, let el = element else { return nil }

        // 只接受真正的文字角色节点（向上最多 6 层）
        var node: AXUIElement = el
        for _ in 0..<6 {
            let role = strAttr(node, kAXRoleAttribute) ?? ""
            if textRoles.contains(role) {
                if let text = strAttr(node, kAXValueAttribute), containsCJK(text) {
                    return trim(text)
                }
            }
            guard let p = parent(of: node) else { break }
            node = p
        }
        return nil
    }

    // MARK: - OCR 路径

    private func getTextViaOCR(at appKitPoint: CGPoint) -> String? {
        guard CGPreflightScreenCaptureAccess() else { return nil }

        // 截取光标周围较大区域（多几行，后面用坐标过滤）
        let axPoint = flip(appKitPoint)
        let captureW: CGFloat = 900
        let captureH: CGFloat = 140
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

        // 光标在截图中的归一化坐标
        // VNBoundingBox 原点在左下角，y 向上
        let normX = (axPoint.x - originX) / captureW
        let normY = 1.0 - (axPoint.y - originY) / captureH   // 翻转 y

        // 优先选包含光标的识别行；若无则选中心最近的
        var best: (dist: CGFloat, text: String)? = nil
        for obs in observations {
            guard obs.confidence > 0.2,
                  let text = try? obs.topCandidates(1).first?.string,
                  containsCJK(text) else { continue }
            let box = obs.boundingBox
            let dx = box.midX - normX
            let dy = box.midY - normY
            let dist = dx * dx + dy * dy
            // 包含光标 → dist 权重为 0，直接优先
            let score: CGFloat = box.contains(CGPoint(x: normX, y: normY)) ? 0 : dist
            if best == nil || score < best!.dist {
                best = (score, text)
            }
        }

        guard let text = best?.text else { return nil }
        return trim(text)
    }

    // MARK: - AX helpers

    private func directText(from el: AXUIElement) -> String? {
        guard !isHidden(el) else { return nil }
        for key in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute] {
            if let v = strAttr(el, key), !v.isEmpty { return v }
        }
        return nil
    }

    private func isHidden(_ el: AXUIElement) -> Bool {
        var val: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXHiddenAttribute as CFString, &val) == .success else { return false }
        return (val as? Bool) ?? false
    }

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

    private func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||
            ($0.value >= 0x3400 && $0.value <= 0x4DBF) ||
            ($0.value >= 0xF900 && $0.value <= 0xFAFF) ||
            ($0.value >= 0x2E80 && $0.value <= 0x2FFF)
        }
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
