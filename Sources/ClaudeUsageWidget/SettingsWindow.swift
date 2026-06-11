import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var apiKey: String = ""
    @State private var budgetText: String = ""
    @State private var hasStoredKey: Bool = false
    let onChange: () -> Void

    var body: some View {
        Form {
            Picker("표시할 사용량", selection: $settings.mode) {
                ForEach(SettingsStore.Mode.allCases) { Text($0.label).tag($0) }
            }
            .onChange(of: settings.mode) { _ in onChange() }

            if settings.mode == .api {
                if hasStoredKey {
                    HStack {
                        Text("Admin API 키: 저장됨 ✓")
                            .font(.caption).foregroundColor(.secondary)
                        Button("키 삭제") {
                            settings.adminAPIKey = nil
                            hasStoredKey = false
                            onChange()
                        }
                    }
                }
                SecureField(hasStoredKey ? "새 키 입력 시 교체" : "Admin API 키 (sk-ant-admin…)", text: $apiKey)
                TextField("월 예산 (USD)", text: $budgetText)
                Button("저장") {
                    if !apiKey.isEmpty {
                        settings.adminAPIKey = apiKey
                        apiKey = ""
                        hasStoredKey = true
                    }
                    if let budget = Double(budgetText), budget > 0 { settings.monthlyBudgetUSD = budget }
                    onChange()
                }
                Text("키는 이 Mac의 키체인에만 저장되며 api.anthropic.com 외에는 전송되지 않습니다.")
                    .font(.caption2).foregroundColor(.secondary)
            } else {
                Text("Claude Code가 로그인되어 있으면 자동으로 동작합니다.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Toggle("로그인 시 자동 실행", isOn: $settings.launchAtLogin)
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            hasStoredKey = settings.adminAPIKey?.isEmpty == false
            budgetText = String(format: "%.0f", settings.monthlyBudgetUSD)
        }
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
