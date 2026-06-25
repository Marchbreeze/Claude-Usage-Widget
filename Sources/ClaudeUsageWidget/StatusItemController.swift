import AppKit
import SwiftUI
import UsageCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let hosting: NSHostingView<StatusBarView>
    private let settings: SettingsStore
    private let menu = NSMenu()

    private var snapshot: UsageSnapshot?
    private var lastError: FetchError?
    private var consecutiveFailures = 0
    private var pollTask: Task<Void, Never>?
    private var settingsWindow: SettingsWindowController?

    init(settings: SettingsStore) {
        self.settings = settings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let restored = SnapshotCache.load()
        snapshot = restored
        let initialProvider = settings.provider
        hosting = NSHostingView(rootView: StatusBarView(model: StatusBarModel(percent: restored?.percent, provider: initialProvider, isStale: restored != nil)))
        super.init()
        statusItem.button?.addSubview(hosting)
        resizeToFit()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        provider = Self.makeProvider(settings)
        startPolling()
    }

    func restartPolling() {
        pollTask?.cancel()
        consecutiveFailures = 0
        provider = Self.makeProvider(settings)
        // The previous provider's snapshot doesn't apply to the new source.
        snapshot = nil
        lastError = nil
        render(percent: nil, isStale: false)
        startPolling()
    }

    private var provider: UsageProvider = SubscriptionProvider()

    private static func makeProvider(_ settings: SettingsStore) -> UsageProvider {
        switch settings.provider {
        case .claude: return SubscriptionProvider()
        case .copilot: return CopilotProvider(overageBudgetUSD: settings.copilotOverageBudgetUSD)
        }
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                let base = self.provider.pollInterval
                let delay = self.consecutiveFailures == 0
                    ? base
                    : min(base * pow(2, Double(self.consecutiveFailures)), 900)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func tick() async {
        do {
            let snap = try await provider.fetch()
            snapshot = snap
            lastError = nil
            consecutiveFailures = 0
            SnapshotCache.save(snap)
            render(percent: snap.percent, isStale: false)
        } catch {
            let fetchError = error as? FetchError ?? .network("\(error)")
            lastError = fetchError
            consecutiveFailures += 1
            switch fetchError {
            case .network:
                render(percent: snapshot?.percent, isStale: true)
            default:
                render(percent: nil, isStale: false)
            }
        }
    }

    private func render(percent: Double?, isStale: Bool) {
        hosting.rootView = StatusBarView(model: StatusBarModel(percent: percent, provider: settings.provider, isStale: isStale))
        resizeToFit()
    }

    private func resizeToFit() {
        let size = hosting.fittingSize
        hosting.frame = NSRect(x: 0, y: 0, width: size.width, height: max(size.height, 22))
        statusItem.length = size.width
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.autoenablesItems = false
        if let snap = snapshot {
            if let cop = snap.copilot {
                if cop.unlimited {
                    menu.addItem(label: "Premium 요청: 무제한")
                } else if let remaining = cop.remaining, let entitlement = cop.entitlement {
                    let used = Int((entitlement - remaining).rounded())
                    menu.addItem(label: "Premium 요청: \(used) / \(Int(entitlement.rounded())) (\(Int(cop.premiumPercent.rounded()))%)")
                } else {
                    menu.addItem(label: "Premium 요청: \(Int(cop.premiumPercent.rounded()))% 사용")
                }
                if !cop.unlimited {
                    if let opct = cop.overagePercent {
                        if let spend = cop.overageSpendUSD, let budget = cop.overageBudgetUSD {
                            menu.addItem(label: String(format: "추가 사용량: $%.2f / $%.0f (%d%%)", spend, budget, Int(opct.rounded())))
                        } else {
                            menu.addItem(label: "추가 사용량: \(Int(opct.rounded()))%")
                        }
                        if let count = cop.overageCount, let ent = cop.overageEntitlement, ent > 0 {
                            menu.addItem(label: "초과 요청: \(Int(count.rounded())) / \(Int(ent.rounded()))")
                        } else if let count = cop.overageCount, count > 0 {
                            menu.addItem(label: "초과 요청: \(Int(count.rounded()))건")
                        }
                    } else if cop.overagePermitted {
                        menu.addItem(label: "추가 사용량: 허용됨")
                    } else {
                        menu.addItem(label: "추가 사용량: 차단됨")
                    }
                }
                if let reset = cop.resetsAt {
                    let when = MonthlyReset.monthDayUTC(reset)
                    let remaining = RelativeTime.until(reset).map { " · \($0)" } ?? ""
                    menu.addItem(label: "월 리셋: \(when)\(remaining)")
                }
                if let plan = cop.plan {
                    menu.addItem(label: "플랜: \(plan)")
                }
            }
            if let sub = snap.subscription {
                if let five = sub.fiveHourPercent {
                    menu.addItem(label: "5시간 세션: \(Int(five.rounded()))% 사용" + countdown(sub.fiveHourResetsAt))
                }
                if let weekly = sub.sevenDayPercent {
                    menu.addItem(label: "주간: \(Int(weekly.rounded()))% 사용" + countdown(sub.sevenDayResetsAt))
                }
                if let extra = sub.extraUsage {
                    if let used = extra.usedUSD, let limit = extra.limitUSD {
                        menu.addItem(label: String(format: "추가 사용량: $%.0f / $%.0f (%d%%)", used, limit, Int(extra.percent.rounded())))
                    } else {
                        menu.addItem(label: "추가 사용량: \(Int(extra.percent.rounded()))% 사용")
                    }
                    if let reset = extra.resetsAt {
                        let when = MonthlyReset.monthDayUTC(reset)
                        let remaining = RelativeTime.until(reset).map { " · \($0)" } ?? ""
                        menu.addItem(label: "월 리셋: \(when)\(remaining)")
                    }
                }
            }
            let age = Int(Date().timeIntervalSince(snap.fetchedAt) / 60)
            if age >= 2 || lastError != nil {
                menu.addItem(label: "마지막 갱신 \(max(age, 1))분 전")
            }
        }
        if let err = lastError {
            menu.addItem(label: "⚠ " + err.userMessage)
        }
        if snapshot == nil && lastError == nil {
            menu.addItem(label: "불러오는 중…")
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "지금 새로고침", action: #selector(refreshNow), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "설정…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func countdown(_ date: Date?) -> String {
        guard let date, let remaining = RelativeTime.until(date) else { return "" }
        return " · 리셋 \(remaining)"
    }

    @objc private func refreshNow() { Task { await tick() } }

    @objc private func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController(settings: settings, onChange: { [weak self] in self?.restartPolling() }) }
        settingsWindow?.show()
    }
}

private extension NSMenu {
    func addItem(label: String) {
        let item = NSMenuItem(title: label, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}
