import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let onChange: () -> Void

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Code가 로그인되어 있으면 사용량이 자동으로 표시됩니다.")
                Text("• 구독 계정: 5시간 세션 사용률")
                Text("• 엔터프라이즈 계정: 추가 사용량(extra usage) 사용률")
            }
            .font(.caption).foregroundColor(.secondary)

            Toggle("로그인 시 자동 실행", isOn: $settings.launchAtLogin)
        }
        .padding(20)
        .frame(width: 360)
    }
}

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(settings: SettingsStore, onChange: @escaping () -> Void) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, onChange: onChange))
        window = NSWindow(contentViewController: hosting)
        window.title = "Claude Usage Widget 설정"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
