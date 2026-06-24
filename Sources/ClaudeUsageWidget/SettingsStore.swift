import Foundation
import ServiceManagement
import UsageCore

final class SettingsStore: ObservableObject {
    private static let providerKey = "provider"
    private static let copilotBudgetKey = "copilotOverageBudgetUSD"
    private static let defaultCopilotBudgetUSD = 10.0

    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }

    /// Which usage source the widget tracks. Defaults to Claude.
    @Published var provider: ProviderKind {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: Self.providerKey) }
    }

    /// Additional-usage (overage) budget cap shown in Copilot mode, in USD.
    @Published var copilotOverageBudgetUSD: Double {
        didSet { UserDefaults.standard.set(copilotOverageBudgetUSD, forKey: Self.copilotBudgetKey) }
    }

    init() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let raw = UserDefaults.standard.string(forKey: Self.providerKey)
        provider = raw.flatMap(ProviderKind.init(rawValue:)) ?? .claude
        let storedBudget = UserDefaults.standard.object(forKey: Self.copilotBudgetKey) as? Double
        copilotOverageBudgetUSD = storedBudget ?? Self.defaultCopilotBudgetUSD
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
