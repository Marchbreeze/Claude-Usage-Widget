import Foundation
import UsageCore

/// Refreshes the Claude Code OAuth access token the same way the CLI does: it POSTs
/// the stored `refreshToken` to Anthropic's token endpoint, then writes the rotated
/// credentials back into the shared keychain item so the widget stays authenticated
/// without a manual `/login` — and the CLI picks up the new refresh token too.
enum ClaudeTokenRefresher {
    static let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    // Public Claude Code OAuth client id.
    static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    /// Attempt a refresh from the raw keychain JSON. On success returns fresh
    /// credentials and updates the keychain in place; on any failure throws
    /// `.needsClaudeLogin` so the UI can prompt for a manual re-login.
    static func refresh(rawCredentials: Data, service: String) async throws -> ClaudeCredentials {
        guard var root = (try? JSONSerialization.jsonObject(with: rawCredentials)) as? [String: Any] else {
            throw FetchError.needsClaudeLogin
        }
        let isWrapped = root["claudeAiOauth"] is [String: Any]
        var oauth = (root["claudeAiOauth"] as? [String: Any]) ?? root
        guard let refreshToken = oauth["refreshToken"] as? String, !refreshToken.isEmpty else {
            throw FetchError.needsClaudeLogin
        }

        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("anthropic", forHTTPHeaderField: "User-Agent")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let newAccess = json["access_token"] as? String, !newAccess.isEmpty else {
            throw FetchError.needsClaudeLogin
        }

        let newRefresh = (json["refresh_token"] as? String) ?? refreshToken
        let expiresAtMs = resolveExpiryMs(json)

        oauth["accessToken"] = newAccess
        oauth["refreshToken"] = newRefresh
        oauth["expiresAt"] = expiresAtMs
        if isWrapped { root["claudeAiOauth"] = oauth } else { root = oauth }
        if let updated = try? JSONSerialization.data(withJSONObject: root) {
            KeychainReader.update(service: service, data: updated)
        }

        return ClaudeCredentials(
            accessToken: newAccess,
            expiresAt: Date(timeIntervalSince1970: expiresAtMs / 1000)
        )
    }

    /// Normalize the server's expiry into epoch milliseconds. Prefer `expires_in`
    /// (seconds from now); otherwise use `expires_at` (accepting either seconds or
    /// milliseconds); default to one hour out.
    private static func resolveExpiryMs(_ json: [String: Any]) -> Double {
        if let expiresIn = number(json["expires_in"]) {
            return Date().addingTimeInterval(expiresIn).timeIntervalSince1970 * 1000
        }
        if let expiresAt = number(json["expires_at"]) {
            return expiresAt > 1_000_000_000_000 ? expiresAt : expiresAt * 1000
        }
        return Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000
    }

    private static func number(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) }
        return nil
    }
}
