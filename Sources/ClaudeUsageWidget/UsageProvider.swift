import Foundation
import UsageCore

enum FetchError: Error, Equatable {
    case needsClaudeLogin
    case network(String)

    var userMessage: String {
        switch self {
        case .needsClaudeLogin: return "Claude Code 로그인이 필요합니다 (터미널에서 claude 실행)"
        case .network(let detail): return "네트워크 오류: \(detail)"
        }
    }
}

protocol UsageProvider {
    var pollInterval: TimeInterval { get }
    func fetch() async throws -> UsageSnapshot
}
