import Foundation

/// Locates a GitHub token usable for Copilot, trying the same places the Copilot
/// CLI and GitHub CLI use, in order of preference:
///   1. env vars (`COPILOT_GITHUB_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN`)
///   2. Copilot CLI device-flow store from `/login`
///      (`~/.copilot/settings.json`, older `config.json`; honors `COPILOT_HOME`/`XDG_CONFIG_HOME`)
///   3. `~/.config/gh/hosts.yml` (plaintext `oauth_token:` for github.com)
///   4. the system keychain (service `gh:github.com`)
///
/// Note: a menu-bar app launched from Finder/LaunchAgent doesn't inherit the
/// shell environment, so the env-var path rarely fires for GUI launches — the
/// Copilot CLI store and gh config are the reliable sources.
enum GHTokenReader {
    static func read() -> String? {
        if let env = environmentToken() { return env }
        if let copilot = copilotStoreToken() { return copilot }
        if let copilotKey = copilotKeychainToken() { return copilotKey }
        if let file = hostsFileToken() { return file }
        if let key = keychainToken() { return key }
        return nil
    }

    /// On macOS the Copilot CLI `/login` (device flow) token is stored in the
    /// system keychain, not in a file. GitHub doesn't document the service name,
    /// so try the likely candidates and pull a GitHub token out of whatever
    /// string we get back (the item may be a JSON blob).
    private static func copilotKeychainToken() -> String? {
        // `copilot-cli` is what the CLI uses on macOS; the rest are fallbacks for
        // other versions/platforms.
        let candidates = [
            "copilot-cli", "GitHub Copilot CLI", "GitHub Copilot",
            "github-copilot", "copilot", "com.github.copilot",
        ]
        for service in candidates {
            guard let data = try? KeychainReader.read(service: service),
                  let raw = String(data: data, encoding: .utf8) else { continue }
            if let token = extractGitHubToken(raw) { return token }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private static func environmentToken() -> String? {
        for key in ["COPILOT_GITHUB_TOKEN", "GH_TOKEN", "GITHUB_TOKEN"] {
            if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty { return v }
        }
        return nil
    }

    // MARK: - Copilot CLI device-flow store (`/login`)

    private static func copilotStoreToken() -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let env = ProcessInfo.processInfo.environment
        var dirs: [URL] = []
        if let copilotHome = env["COPILOT_HOME"], !copilotHome.isEmpty {
            dirs.append(URL(fileURLWithPath: copilotHome))
        }
        if let xdg = env["XDG_CONFIG_HOME"], !xdg.isEmpty {
            dirs.append(URL(fileURLWithPath: xdg).appendingPathComponent("copilot"))
        }
        dirs.append(home.appendingPathComponent(".copilot"))

        for dir in dirs {
            for name in ["settings.json", "config.json"] {
                let url = dir.appendingPathComponent(name)
                guard let text = try? String(contentsOf: url, encoding: .utf8),
                      let token = Self.extractGitHubToken(text) else { continue }
                return token
            }
        }
        return nil
    }

    /// Finds the first GitHub token in arbitrary text, without assuming the JSON
    /// shape (which varies across Copilot CLI versions). Matches the standard
    /// GitHub token prefixes.
    static func extractGitHubToken(_ text: String) -> String? {
        let pattern = "(gho_|ghu_|ghp_|ghs_)[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }

    // MARK: - GitHub CLI (`gh auth login`)

    private static func hostsFileToken() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".config/gh/hosts.yml"),
            home.appendingPathComponent(".config/gh/hosts.yaml"),
        ]
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return Self.parseOAuthToken(text, host: "github.com")
    }

    /// Minimal YAML scan: find the `github.com:` block and return its `oauth_token`.
    /// Avoids a YAML dependency; the file is machine-generated with stable shape.
    static func parseOAuthToken(_ yaml: String, host: String) -> String? {
        let lines = yaml.components(separatedBy: .newlines)
        var inHost = false
        for line in lines {
            // A non-indented `host:` line opens/closes a top-level block.
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && line.contains(":") {
                inHost = line.trimmingCharacters(in: .whitespaces).hasPrefix("\(host):")
            }
            if inHost, let range = line.range(of: "oauth_token:") {
                let value = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    private static func keychainToken() -> String? {
        guard let data = try? KeychainReader.read(service: "gh:github.com"),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
