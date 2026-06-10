import Foundation
import UsageCore

enum FetchError: Error, Equatable {
    case needsClaudeLogin
    case needsAPIKey
    case invalidAPIKey
    case needsBudget
    case network(String)

    var userMessage: String {
        switch self {
        case .needsClaudeLogin: return "Claude Code 로그인이 필요합니다 (터미널에서 claude 실행)"
        case .needsAPIKey: return "설정에서 Admin API 키를 입력하세요"
        case .invalidAPIKey: return "API 키가 올바르지 않습니다"
        case .needsBudget: return "설정에서 월 예산을 입력하세요"
        case .network(let detail): return "네트워크 오류: \(detail)"
        }
    }
}

protocol UsageProvider {
    var pollInterval: TimeInterval { get }
    func fetch() async throws -> UsageSnapshot
}
