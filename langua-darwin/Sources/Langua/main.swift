import AppKit

// SPM executableTarget 的入口：直接启动 NSApplication，
// 不用 @main App 协议（避免 SwiftUI 生命周期对 applicationDidFinishLaunching 时序的干扰）
let _delegate = AppDelegate()
NSApplication.shared.delegate = _delegate
NSApplication.shared.run()
