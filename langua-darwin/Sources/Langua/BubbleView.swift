import SwiftUI

// MARK: - 气泡容器

struct BubbleView: View {
    let chars: [AnnotatedChar]

    // 最多显示行数，超长文字拆成多行（每行约 20 个 CJK）
    private let charsPerRow = 20

    private var rows: [[AnnotatedChar]] {
        stride(from: 0, to: chars.count, by: charsPerRow).map {
            Array(chars[$0 ..< min($0 + charsPerRow, chars.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(row) { ac in
                        CharCell(char: ac.char, pinyin: ac.pinyin)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.078, green: 0.078, blue: 0.078, opacity: 0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
        )
        // 投影由 NSPanel.hasShadow 提供，此处不重复
    }
}

// MARK: - 单字单元格
// 仿 HTML <ruby> 布局：格子宽 = max(拼音宽, 汉字宽)，两者居中，拼音不截断

struct CharCell: View {
    let char: String
    let pinyin: String?

    private var isHanzi: Bool { isCJK(char) }

    var body: some View {
        VStack(spacing: 1) {
            // 拼音行：fixedSize 让它取自然宽度，不截断，不缩小
            if let py = pinyin {
                Text(py)
                    .foregroundColor(Color(red: 0.494, green: 0.722, blue: 0.980))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else if isHanzi {
                // 非拼音汉字（罕见）也占一行高度，保持行内垂直对齐一致
                Color.clear.frame(width: 1, height: 14)
            }

            // 汉字 / 字符：fixedSize 取自然宽度
            Text(char)
                .font(isHanzi
                      ? .system(size: 18, weight: .regular)
                      : .system(size: 15, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        // 最小宽度保证汉字不过窄；VStack 默认居中对齐，拼音与字自动居中
        .frame(minWidth: isHanzi ? 22 : nil, alignment: .center)
    }

    private func isCJK(_ s: String) -> Bool {
        guard let scalar = s.unicodeScalars.first else { return false }
        return (scalar.value >= 0x4E00 && scalar.value <= 0x9FFF) ||
               (scalar.value >= 0x3400 && scalar.value <= 0x4DBF)
    }
}

// MARK: - 菜单栏内容面板

struct MenuBarContent: View {
    @EnvironmentObject var state: AppState
    /// 每秒轮询，在系统设置里开启权限后自动消除警告
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题
            HStack {
                Text("langua")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.494, green: 0.906, blue: 0.980))
                Text("懒瓜")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Circle()
                    .fill(state.enabled && state.isAccessibilityGranted ? Color.green : Color.gray)
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().padding(.horizontal, 10)

            // 辅助功能权限状态
            if !state.isAccessibilityGranted {
                Button {
                    // 直接跳转到「系统设置 → 隐私与安全性 → 辅助功能」
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 13))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("需要辅助功能权限")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            Text("点击前往系统设置开启")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider().padding(.horizontal, 10)
            }

            // 屏幕录制权限（用于 OCR 兜底，微信/Electron 等 App 必须）
            if !state.isScreenRecordingGranted {
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("建议开启屏幕录制权限")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            Text("微信等 App 需要此权限读取文字")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                Divider().padding(.horizontal, 10)
            }

            // 启用开关
            Toggle(isOn: $state.enabled) {
                Text("启用悬停拼音")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)

            Toggle(isOn: $state.selectionEnabled) {
                Text("启用划词拼音")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 10)

            // 悬停延迟调节
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("悬停延迟")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(state.hoverDelayMs)) ms")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Slider(value: $state.hoverDelayMs, in: 100...800, step: 50)
                    .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 10)

            // 退出
            Button {
                NSApp.terminate(nil)
            } label: {
                Text("退出 langua")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 220)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { state.refreshAccessibility() }
        // 每秒检查一次，在系统设置开启后自动刷新（无需重启 app）
        .onReceive(timer) { _ in
            guard !state.isAccessibilityGranted else { return }
            state.refreshAccessibility()
        }
    }
}
