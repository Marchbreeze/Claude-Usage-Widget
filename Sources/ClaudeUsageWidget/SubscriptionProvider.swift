import Foundation
import UsageCore

final class SubscriptionProvider: UsageProvider {
    let pollInterval: TimeInterval = 60
    static let credentialsService = "Claude Code-credentials"

    private var cachedCredentials: ClaudeCredentials?

    func fetch() async throws -> UsageSnapshot {
        let creds = try loadCredentials()
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FetchError.network("응답 없음") }
        if http.statusCode == 401 || http.statusCode == 403 {
            cachedCredentials = nil
            throw FetchError.needsClaudeLogin
        }
        guard http.statusCode == 200 else { throw FetchError.network("HTTP \(http.statusCode)") }
        guard let detail = try? OAuthUsageParser.parse(data) else { throw FetchError.network("응답 형식 오류") }
        let percent = detail.fiveHourPercent ?? detail.extraUsage?.percent ?? 0
        return UsageSnapshot(percent: percent, subscription: detail, fetchedAt: Date())
    }

    private func loadCredentials() throws -> ClaudeCredentials {
        let buffer: TimeInterval = 120
        if let cached = cachedCredentials, !cached.isExpired(now: Date().addingTimeInterval(buffer)) {
            return cached
        }
        let credData: Data
        do { credData = try KeychainReader.read(service: Self.credentialsService) }
        catch { throw FetchError.needsClaudeLogin }
        guard let creds = try? CredentialsParser.parse(credData), !creds.isExpired() else {
            throw FetchError.needsClaudeLogin
        }
        cachedCredentials = creds
        return creds
    }
}
