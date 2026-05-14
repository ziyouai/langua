import Foundation
import JavaScriptCore

struct AnnotatedChar: Identifiable {
    let id = UUID()
    let char: String        // 单个字符（CJK 或标点/空格）
    let pinyin: String?     // 若无拼音（非 CJK）则为 nil
}

/// 通过 JavaScriptCore 复用插件的 pinyin-data.js + segmenter.js，
/// 避免重写字典和分词逻辑。
final class PinyinEngine {
    static let shared = PinyinEngine()

    private let context = JSContext()!
    private var ready = false

    private init() {
        context.exceptionHandler = { _, ex in
            print("[PinyinEngine] JS error:", ex?.toString() ?? "unknown")
        }
        // 浏览器全局对象 shim（某些 JS 文件可能引用 window / globalThis）
        context.evaluateScript("var window = this; var globalThis = this; var self = this;")
        // 按依赖顺序加载（与 packages/core/RULES.md 保持一致）
        loadScript("pinyin-data")   // → 定义 CHAR_DICT（常用字，约 6500 字）
        loadExtDict()               // → 补全 CHAR_DICT（全量 CJK，约 20902 字）
        loadScript("units-data")    // → 定义 UNITS_DICT
        loadScript("segmenter")     // → 定义 Segmenter（依赖 CHAR_DICT）
        // 注入包装函数，供 Swift 调用
        context.evaluateScript("""
        function _langua_annotate(text) {
            if (typeof Segmenter === 'undefined') return [];
            try {
                var tokens = Segmenter.segment(text);
                var result = [];
                for (var t = 0; t < tokens.length; t++) {
                    var tok = tokens[t];
                    var word = tok.word;
                    for (var i = 0; i < word.length; i++) {
                        var ch = word.charAt(i);
                        var py = (tok.pinyin && tok.pinyin[i]) ? tok.pinyin[i] : '';
                        result.push({ ch: ch, py: py });
                    }
                }
                return result;
            } catch(e) { return []; }
        }
        """)
        // 验证：用 typeof 检查（const/let 声明不挂在 globalObject 上，但 typeof 可访问）
        let check = context.evaluateScript(
            "typeof Segmenter !== 'undefined' && typeof Segmenter.segment === 'function'"
        )
        ready = check?.toBool() ?? false
        if !ready { print("[PinyinEngine] ⚠️  Segmenter not found — JS files may be missing") }
    }

    /// 将文本拆分为 AnnotatedChar 数组，每个 CJK 字符附带拼音。
    func annotate(_ text: String) -> [AnnotatedChar] {
        guard ready, !text.isEmpty else { return [] }
        // 转义防止 JS 注入
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
        guard let result = context.evaluateScript("_langua_annotate('\(escaped)')"),
              let arr = result.toArray() else { return [] }
        return arr.compactMap { item -> AnnotatedChar? in
            guard let dict = item as? [String: Any],
                  let ch = dict["ch"] as? String else { return nil }
            let py = (dict["py"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return AnnotatedChar(char: ch, pinyin: py)
        }
    }

    // MARK: - Private

    private func loadScript(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else {
            print("[PinyinEngine] ⚠️  Missing resource: \(name).js")
            return
        }
        guard let src = try? String(contentsOf: url, encoding: .utf8) else { return }
        context.evaluateScript(src)
    }

    /// 加载全量 CJK 字典（pinyin-ext.json），补全 CHAR_DICT 中没有的字符。
    /// 用 Swift/Foundation 解析 JSON → 直接 setObject 注入 JSContext，
    /// 避免大字符串插值 + JSCore const 作用域的不确定性。
    private func loadExtDict() {
        guard let url = Bundle.main.url(forResource: "pinyin-ext", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            print("[PinyinEngine] ⚠️  Missing or invalid pinyin-ext.json")
            return
        }
        // 将 Swift Array 直接注入为 JS 全局变量，无需二次 parse
        context.setObject(arr, forKeyedSubscript: "__langua_ext__" as NSString)
        context.evaluateScript("""
        if (typeof CHAR_DICT !== 'undefined' && typeof __langua_ext__ !== 'undefined') {
            var _extStart = 0x4E00;
            for (var _i = 0; _i < __langua_ext__.length; _i++) {
                if (__langua_ext__[_i]) {
                    var _ch = String.fromCharCode(_extStart + _i);
                    if (!CHAR_DICT[_ch]) CHAR_DICT[_ch] = __langua_ext__[_i];
                }
            }
        }
        __langua_ext__ = undefined;
        """)
        print("[PinyinEngine] ✅ pinyin-ext.json 加载完成（\(arr.count) 条）")
    }
}
