import AppKit
import SwiftUI
import UsageCore

private extension Text {
    /// Left-aligned, full-width, multi-line caption that never gets pushed into a
    /// trailing column or truncated.
    func caption(_ secondary: Bool = true) -> some View {
        self.font(.caption)
            .foregroundColor(secondary ? .secondary : .primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let onChange: () -> Void
    let onDisplayChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("사용량 소스").font(.headline)
                Picker("사용량 소스", selection: $settings.provider) {
                    Text("Claude").tag(ProviderKind.claude)
                    Text("GitHub Copilot").tag(ProviderKind.copilot)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .onChange(of: settings.provider) { _ in onChange() }
            }

            if settings.provider == .claude {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude Code가 로그인되어 있으면 사용량이 자동으로 표시됩니다.").caption()
                    Text("• 구독 계정: 5시간 세션 사용률").caption()
                    Text("• 엔터프라이즈 계정: 추가 사용량(extra usage) 사용률").caption()
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copilot CLI에 로그인되어 있으면 사용량이 자동으로 표시됩니다.").caption()
                    Text("• 이번 달 premium request 사용률").caption()
                    Text("• 100% 소진 시 추가 사용량(%)으로 자동 전환").caption()
                    Text("• 로그인이 필요하면 터미널에서 copilot 실행 후 /login").caption()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Stepper(value: $settings.copilotOverageBudgetUSD, in: 0...500, step: 1) {
                        Text(settings.copilotOverageBudgetUSD > 0
                             ? "추가 사용량 한도(표시용): $\(Int(settings.copilotOverageBudgetUSD))"
                             : "추가 사용량 한도(표시용): 없음 (%만 표시)")
                    }
                    .onChange(of: settings.copilotOverageBudgetUSD) { _ in onChange() }

                    Text("게이지는 API 값(overage_count / entitlement)으로 계산되어 한도와 무관하게 정확합니다. 한도는 \"$사용 / $한도\" 라벨에만 쓰입니다.").caption()
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Picker("퍼센트 표시 형식", selection: $settings.percentDecimals) {
                    Text("정수").tag(0)
                    Text("소수점 1자리").tag(1)
                    Text("소수점 2자리").tag(2)
                }
                .onChange(of: settings.percentDecimals) { _ in onDisplayChange() }
            }

            Toggle("로그인 시 자동 실행", isOn: $settings.launchAtLogin)
        }
        .padding(20)
        .frame(width: 380, alignment: .leading)
    }
}

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(settings: SettingsStore, onChange: @escaping () -> Void, onDisplayChange: @escaping () -> Void) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, onChange: onChange, onDisplayChange: onDisplayChange))
        window = NSWindow(contentViewController: hosting)
        window.title = "Usage Widget 설정"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
