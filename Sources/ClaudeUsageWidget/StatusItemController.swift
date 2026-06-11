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
        hosting = NSHostingView(rootView: StatusBarView(model: StatusBarModel(percent: restored?.percent, isStale: restored != nil)))
        super.init()
        statusItem.button?.addSubview(hosting)
        resizeToFit()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        startPolling()
    }

    func restartPolling() {
        pollTask?.cancel()
        consecutiveFailures = 0
        provider = Self.makeProvider(for: settings)
        startPolling()
    }

    private lazy var provider: UsageProvider = Self.makeProvider(for: settings)

    private static func makeProvider(for settings: SettingsStore) -> UsageProvider {
        settings.mode == .subscription ? SubscriptionProvider() : APICostProvider(settings: settings)
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
        let activeMode = settings.mode
        do {
            let snap = try await provider.fetch()
            guard settings.mode == activeMode else { return }
            snapshot = snap
            lastError = nil
            consecutiveFailures = 0
            SnapshotCache.save(snap)
            render(percent: snap.percent, isStale: false)
        } catch {
            guard settings.mode == activeMode else { return }
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
        hosting.rootView = StatusBarView(model: StatusBarModel(percent: percent, isStale: isStale))
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
            if let sub = snap.subscription {
                menu.addItem(label: "5시간 세션: \(Int(sub.fiveHourPercent.rounded()))% 사용" + countdown(sub.fiveHourResetsAt))
                if let weekly = sub.sevenDayPercent {
                    menu.addItem(label: "주간: \(Int(weekly.rounded()))% 사용" + countdown(sub.sevenDayResetsAt))
                }
            }
            if let api = snap.api {
                menu.addItem(label: String(format: "이번 달 지출: $%.2f / $%.0f", api.spendUSD, api.budgetUSD))
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
        guard let date, date > Date() else { return "" }
        let mins = Int(date.timeIntervalSinceNow / 60)
        return mins >= 60 ? " · 리셋 \(mins / 60)시간 \(mins % 60)분 후" : " · 리셋 \(mins)분 후"
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
