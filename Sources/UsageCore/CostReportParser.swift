import Foundation

public struct CostPage: Equatable {
    public let amountUSD: Double
    public let hasMore: Bool
    public let nextPage: String?
    public init(amountUSD: Double, hasMore: Bool, nextPage: String?) {
        self.amountUSD = amountUSD
        self.hasMore = hasMore
        self.nextPage = nextPage
    }
}

public enum CostReportError: Error, Equatable { case malformed }

public enum CostReportParser {
    public static func parse(_ data: Data) throws -> CostPage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buckets = root["data"] as? [[String: Any]] else {
            throw CostReportError.malformed
        }
        var total = 0.0
        for bucket in buckets {
            for result in (bucket["results"] as? [[String: Any]]) ?? [] {
                if let s = result["amount"] as? String, let v = Double(s) { total += v }
                else if let v = result["amount"] as? Double { total += v }
            }
        }
        return CostPage(
            amountUSD: total,
            hasMore: root["has_more"] as? Bool ?? false,
            nextPage: root["next_page"] as? String
        )
    }
}
