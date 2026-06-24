import Foundation
import UsageCore

/// Reads GitHub Copilot premium-request usage from `/copilot_internal/user` — the
/// same endpoint the official IDE extensions use — authenticated with the token
/// from the user's `gh auth login` session.
final class CopilotProvider: UsageProvider {
    let pollInterval: TimeInterval = 60

    func fetch() async throws -> UsageSnapshot {
        guard let token = GHTokenReader.read() else { throw FetchError.needsGitHubLogin }

        var req = URLRequest(url: URL(string: "https://api.github.com/copilot_internal/user")!)
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        // The internal endpoint expects an editor identity; mirror the IDE clients.
        req.setValue("ClaudeUsageWidget/1.0", forHTTPHeaderField: "User-Agent")
        req.setValue("vscode/1.99.0", forHTTPHeaderField: "Editor-Version")
        req.setValue("copilot/1.0.0", forHTTPHeaderField: "Editor-Plugin-Version")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FetchError.network("응답 없음") }
        if http.statusCode == 401 || http.statusCode == 403 { throw FetchError.needsGitHubLogin }
        guard http.statusCode == 200 else { throw FetchError.network("HTTP \(http.statusCode)") }
        guard let detail = try? CopilotUsageParser.parse(data) else { throw FetchError.network("응답 형식 오류") }

        return UsageSnapshot(percent: detail.premiumPercent, provider: .copilot, copilot: detail, fetchedAt: Date())
    }
}
