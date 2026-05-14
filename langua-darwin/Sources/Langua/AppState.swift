import ApplicationServices
import Combine
import CoreGraphics
import Foundation

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var enabled: Bool = true {
        didSet { UserDefaults.standard.set(enabled, forKey: "langua_enabled") }
    }

    @Published var hoverDelayMs: Double = 400 {
        didSet { UserDefaults.standard.set(hoverDelayMs, forKey: "langua_hoverDelay") }
    }

    @Published var selectionEnabled: Bool = true {
        didSet { UserDefaults.standard.set(selectionEnabled, forKey: "langua_selectionEnabled") }
    }

    @Published var isAccessibilityGranted: Bool = false
    @Published var isScreenRecordingGranted: Bool = false

    var cancellables = Set<AnyCancellable>()

    func refreshAccessibility() {
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(nil)
        isScreenRecordingGranted = CGPreflightScreenCaptureAccess()
    }

    private init() {
        if UserDefaults.standard.object(forKey: "langua_enabled") != nil {
            enabled = UserDefaults.standard.bool(forKey: "langua_enabled")
        }
        if UserDefaults.standard.object(forKey: "langua_hoverDelay") != nil {
            hoverDelayMs = UserDefaults.standard.double(forKey: "langua_hoverDelay")
        }
        if UserDefaults.standard.object(forKey: "langua_selectionEnabled") != nil {
            selectionEnabled = UserDefaults.standard.bool(forKey: "langua_selectionEnabled")
        }
    }
}
