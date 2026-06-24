import Foundation
import ServiceManagement
import UsageCore

final class SettingsStore: ObservableObject {
    private static let providerKey = "provider"

    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }

    /// Which usage source the widget tracks. Defaults to Claude.
    @Published var provider: ProviderKind {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: Self.providerKey) }
    }

    init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let raw = UserDefaults.standard.string(forKey: Self.providerKey)
        provider = raw.flatMap(ProviderKind.init(rawValue:)) ?? .claude
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
