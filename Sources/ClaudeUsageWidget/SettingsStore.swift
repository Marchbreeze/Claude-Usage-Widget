import Foundation
import ServiceManagement

final class SettingsStore: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }

    init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("launch-at-login failed: \(error)")
        }
    }
}
