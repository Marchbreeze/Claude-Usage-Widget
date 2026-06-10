import Foundation
import UsageCore

struct APICostProvider: UsageProvider {
    let settings: SettingsStore
    let pollInterval: TimeInterval = 300

    func fetch() async throws -> UsageSnapshot {
        guard let key = settings.adminAPIKey, !key.isEmpty else { throw FetchError.needsAPIKey }
        let budget = settings.monthlyBudgetUSD
        guard budget > 0 else { throw FetchError.needsBudget }

        var total = 0.0
        var page: String?
        var pageCount = 0
        repeat {
            var comps = URLComponents(string: "https://api.anthropic.com/v1/organizations/cost_report")!
            var items = [
                URLQueryItem(name: "starting_at", value: ISODate.string(from: MonthWindow.start())),
                URLQueryItem(name: "limit", value: "31"),
            ]
            if let page { items.append(URLQueryItem(name: "page", value: page)) }
            comps.queryItems = items
            var req = URLRequest(url: comps.url!)
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw FetchError.network("응답 없음") }
            if http.statusCode == 401 || http.statusCode == 403 { throw FetchError.invalidAPIKey }
            guard http.statusCode == 200 else { throw FetchError.network("HTTP \(http.statusCode)") }
            guard let parsed = try? CostReportParser.parse(data) else { throw FetchError.network("응답 형식 오류") }
            total += parsed.amountUSD
            page = parsed.hasMore ? parsed.nextPage : nil
            pageCount += 1
        } while page != nil && pageCount < 24

        let percent = PercentMath.budgetPercent(spend: total, budget: budget) ?? 0
        return UsageSnapshot(source: .api, percent: percent, subscription: nil,
                             api: APIDetail(spendUSD: total, budgetUSD: budget), fetchedAt: Date())
    }
}
