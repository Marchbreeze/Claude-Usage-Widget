import Foundation
import UsageCore

struct SubscriptionProvider: UsageProvider {
    let pollInterval: TimeInterval = 60
    static let credentialsService = "Claude Code-credentials"

    func fetch() async throws -> UsageSnapshot {
        let credData: Data
        do { credData = try KeychainReader.read(service: Self.credentialsService) }
        catch { throw FetchError.needsClaudeLogin }
        guard let creds = try? CredentialsParser.parse(credData), !creds.isExpired() else {
            throw FetchError.needsClaudeLogin
        }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FetchError.network("응답 없음") }
        if http.statusCode == 401 || http.statusCode == 403 { throw FetchError.needsClaudeLogin }
        guard http.statusCode == 200 else { throw FetchError.network("HTTP \(http.statusCode)") }
        guard let detail = try? OAuthUsageParser.parse(data) else { throw FetchError.network("응답 형식 오류") }
        return UsageSnapshot(source: .subscription, percent: detail.fiveHourPercent,
                             subscription: detail, api: nil, fetchedAt: Date())
    }
}
