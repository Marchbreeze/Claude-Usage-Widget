import Foundation

/// Locates the GitHub OAuth token created by `gh auth login`, trying the same
/// places the GitHub CLI itself uses, in order of preference:
///   1. `GH_TOKEN` / `GITHUB_TOKEN` environment variables
///   2. `~/.config/gh/hosts.yml` (plaintext `oauth_token:` for github.com)
///   3. the system keychain (service `gh:github.com`, written when secure storage is on)
enum GHTokenReader {
    static func read() -> String? {
        if let env = environmentToken() { return env }
        if let file = hostsFileToken() { return file }
        if let key = keychainToken() { return key }
        return nil
    }

    private static func environmentToken() -> String? {
        for key in ["GH_TOKEN", "GITHUB_TOKEN"] {
            if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty { return v }
        }
        return nil
    }

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
