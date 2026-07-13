import Foundation
import UsageCore

final class SubscriptionProvider: UsageProvider {
    let pollInterval: TimeInterval = 60
    static let credentialsService = "Claude Code-credentials"

    private var cachedCredentials: ClaudeCredentials?

    func fetch() async throws -> UsageSnapshot {
        let creds = try await loadCredentials()
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FetchError.network("응답 없음") }
        if http.statusCode == 401 || http.statusCode == 403 {
            // Token rejected mid-session. Drop the cache so the next poll re-reads the
            // keychain and attempts a refresh before surfacing a login prompt.
            cachedCredentials = nil
            throw FetchError.needsClaudeLogin
        }
        if http.statusCode == 429 {
            throw FetchError.network("요청 제한(429) · 잠시 후 재시도")
        }
        guard http.statusCode == 200 else { throw FetchError.network("HTTP \(http.statusCode)") }
        guard let detail = try? OAuthUsageParser.parse(data) else { throw FetchError.network("응답 형식 오류") }
        let percent = detail.fiveHourPercent ?? detail.extraUsage?.percent ?? 0
        return UsageSnapshot(percent: percent, subscription: detail, fetchedAt: Date())
    }

    private func loadCredentials() async throws -> ClaudeCredentials {
        let buffer: TimeInterval = 120
        if let cached = cachedCredentials, !cached.isExpired(now: Date().addingTimeInterval(buffer)) {
            return cached
        }

        let credData: Data
        do { credData = try KeychainReader.read(service: Self.credentialsService) }
        catch { throw FetchError.needsClaudeLogin }

        guard let creds = try? CredentialsParser.parse(credData) else {
            throw FetchError.needsClaudeLogin
        }

        // Still valid (possibly just refreshed by the CLI) → use it directly.
        if !creds.isExpired(now: Date().addingTimeInterval(buffer)) {
            cachedCredentials = creds
            return creds
        }

        // Expired/near-expiry: refresh it ourselves and persist the rotated tokens.
        do {
            let refreshed = try await ClaudeTokenRefresher.refresh(
                rawCredentials: credData, service: Self.credentialsService)
            cachedCredentials = refreshed
            return refreshed
        } catch {
            // The CLI may have refreshed concurrently — re-read once before giving up.
            if let latest = try? KeychainReader.read(service: Self.credentialsService),
               let fresh = try? CredentialsParser.parse(latest),
               !fresh.isExpired() {
                cachedCredentials = fresh
                return fresh
            }
            cachedCredentials = nil
            throw FetchError.needsClaudeLogin
        }
    }
}
