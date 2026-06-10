import Foundation

public struct ClaudeCredentials: Equatable {
    public let accessToken: String
    public let expiresAt: Date?
    public init(accessToken: String, expiresAt: Date?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
    }
    public func isExpired(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }
}

public enum CredentialsError: Error, Equatable { case malformed, missingToken }

public enum CredentialsParser {
    public static func parse(_ data: Data) throws -> ClaudeCredentials {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CredentialsError.malformed
        }
        let oauth = (root["claudeAiOauth"] as? [String: Any]) ?? root
        guard let token = oauth["accessToken"] as? String, !token.isEmpty else {
            throw CredentialsError.missingToken
        }
        var expires: Date?
        if let ms = oauth["expiresAt"] as? Double, ms > 0 {
            expires = Date(timeIntervalSince1970: ms / 1000)
        }
        return ClaudeCredentials(accessToken: token, expiresAt: expires)
    }
}
