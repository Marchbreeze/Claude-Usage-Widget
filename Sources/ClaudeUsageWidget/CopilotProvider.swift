import Foundation
import UsageCore

/// Reads GitHub Copilot premium-request usage from `/copilot_internal/user` — the
/// same endpoint the official IDE extensions use — authenticated with the token
/// from the user's Copilot CLI `/login` (or `gh`) session.
final class CopilotProvider: UsageProvider {
    let pollInterval: TimeInterval = 60

    /// GitHub bills premium requests over the included allowance at this flat
    /// rate on every paid plan.
    static let overagePricePerRequestUSD = 0.04

    /// The user's additional-usage (overage) budget cap in USD.
    private let overageBudgetUSD: Double
    /// Cache the token so we don't hit the keychain on every poll (which would
    /// re-trigger the macOS access prompt). Cleared on auth failure.
    private var cachedToken: String?

    init(overageBudgetUSD: Double) {
        self.overageBudgetUSD = overageBudgetUSD
    }

    func fetch() async throws -> UsageSnapshot {
        let token = cachedToken ?? GHTokenReader.read()
        guard let token else { throw FetchError.needsGitHubLogin }

        var req = URLRequest(url: URL(string: "https://api.github.com/copilot_internal/user")!)
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        // The internal endpoint expects an editor identity; mirror the IDE clients.
        req.setValue("ClaudeUsageWidget/1.0", forHTTPHeaderField: "User-Agent")
        req.setValue("vscode/1.99.0", forHTTPHeaderField: "Editor-Version")
        req.setValue("copilot/1.0.0", forHTTPHeaderField: "Editor-Plugin-Version")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FetchError.network("응답 없음") }
        if http.statusCode == 401 || http.statusCode == 403 {
            cachedToken = nil
            throw FetchError.needsGitHubLogin
        }
        guard http.statusCode == 200 else { throw FetchError.network("HTTP \(http.statusCode)") }
        guard let parsed = try? CopilotUsageParser.parse(data) else { throw FetchError.network("응답 형식 오류") }
        cachedToken = token

        let (detail, percent) = applyOverage(parsed)
        return UsageSnapshot(percent: percent, provider: .copilot, copilot: detail, fetchedAt: Date())
    }

    /// Once the included quota is exhausted and paid overage is active, switch the
    /// displayed figure to additional-usage spend ($ used / $ budget). Otherwise
    /// keep showing premium-request usage as a percent of the allowance.
    private func applyOverage(_ d: CopilotDetail) -> (CopilotDetail, Double) {
        let exhausted = d.premiumPercent >= 100 || (d.remaining ?? 1) <= 0
        // Once the included quota is exhausted AND paid overage is permitted, move
        // to the additional-usage stage (the $ meter starts at $0, even before the
        // first overage request). If overage is not permitted, stay pinned at 100%.
        let inOverage = exhausted && d.overagePermitted && overageBudgetUSD > 0
        let spend: Double? = inOverage ? overageSpend(d) : nil
        let detail = CopilotDetail(
            plan: d.plan,
            premiumPercent: d.premiumPercent,
            remaining: d.remaining,
            entitlement: d.entitlement,
            unlimited: d.unlimited,
            overageCount: d.overageCount,
            overageEntitlement: d.overageEntitlement,
            overagePermitted: d.overagePermitted,
            resetsAt: d.resetsAt,
            overageSpendUSD: spend,
            overageBudgetUSD: overageBudgetUSD > 0 ? overageBudgetUSD : nil
        )
        let percent = spend.map { PercentMath.clamp($0 / overageBudgetUSD * 100) } ?? d.premiumPercent
        return (detail, percent)
    }

    /// Additional-usage spend in USD. For token-based-billing accounts the flat
    /// $0.04/request rate doesn't apply; instead `overage_entitlement` is the unit
    /// cap that maps to the dollar budget (e.g. 1000 units ↔ $10), so spend tracks
    /// `overage_count / overage_entitlement × budget`. Falls back to the flat rate
    /// when no entitlement is reported.
    private func overageSpend(_ d: CopilotDetail) -> Double {
        let count = d.overageCount ?? 0
        if let entitlement = d.overageEntitlement, entitlement > 0 {
            return count / entitlement * overageBudgetUSD
        }
        return count * Self.overagePricePerRequestUSD
    }
}
