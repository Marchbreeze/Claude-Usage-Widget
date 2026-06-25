import AppKit
import SwiftUI
import UsageCore

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let onChange: () -> Void

    var body: some View {
        Form {
            Picker("사용량 소스", selection: $settings.provider) {
                Text("Claude").tag(ProviderKind.claude)
                Text("GitHub Copilot").tag(ProviderKind.copilot)
            }
            .pickerStyle(.segmented)
            .onChange(of: settings.provider) { _ in onChange() }

            if settings.provider == .claude {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude Code가 로그인되어 있으면 사용량이 자동으로 표시됩니다.")
                    Text("• 구독 계정: 5시간 세션 사용률")
                    Text("• 엔터프라이즈 계정: 추가 사용량(extra usage) 사용률")
                }
                .font(.caption).foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copilot CLI에 로그인되어 있으면 사용량이 자동으로 표시됩니다.")
                    Text("• 이번 달 premium request 사용률")
                    Text("• 100% 소진 시 추가 사용량(%)으로 자동 전환")
                    Text("• 로그인이 필요하면 터미널에서 copilot 실행 후 /login")
                }
                .font(.caption).foregroundColor(.secondary)

                Stepper(value: $settings.copilotOverageBudgetUSD, in: 0...500, step: 1) {
                    Text(settings.copilotOverageBudgetUSD > 0
                         ? "추가 사용량 한도(표시용): $\(Int(settings.copilotOverageBudgetUSD))"
                         : "추가 사용량 한도(표시용): 없음 (%만 표시)")
                }
                .onChange(of: settings.copilotOverageBudgetUSD) { _ in onChange() }

                Text("게이지는 API 값(overage_count / entitlement)으로 계산되어 한도 입력과 무관하게 정확합니다. 한도는 \"$사용 / $한도\" 라벨 표시에만 쓰입니다.")
                    .font(.caption2).foregroundColor(.secondary)
            }

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
