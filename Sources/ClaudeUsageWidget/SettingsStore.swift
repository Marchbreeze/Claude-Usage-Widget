import Foundation
import ServiceManagement

final class SettingsStore: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case subscription, api
        var id: String { rawValue }
        var label: String { self == .subscription ? "구독 (Claude Code)" : "API (Admin 키)" }
    }

    private static let apiKeyService = "ClaudeUsageWidget-admin-key"
    private let defaults = UserDefaults.standard

    @Published var mode: Mode {
        didSet { defaults.set(mode.rawValue, forKey: "mode") }
    }
    @Published var monthlyBudgetUSD: Double {
        didSet { defaults.set(monthlyBudgetUSD, forKey: "monthlyBudgetUSD") }
    }
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }

    var adminAPIKey: String? {
        get { (try? KeychainReader.read(service: Self.apiKeyService)).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainReader.write(service: Self.apiKeyService, data: Data(newValue.utf8))
            } else {
                KeychainReader.delete(service: Self.apiKeyService)
            }
            objectWillChange.send()
        }
    }

    init() {
        mode = Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .subscription
        let budget = defaults.object(forKey: "monthlyBudgetUSD") as? Double
        monthlyBudgetUSD = budget ?? 200
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
