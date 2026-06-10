import Foundation

public enum OAuthUsageError: Error, Equatable { case malformed, missingFiveHour }

public enum OAuthUsageParser {
    public static func parse(_ data: Data) throws -> SubscriptionDetail {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthUsageError.malformed
        }
        guard let fiveHour = window(root["five_hour"]) else { throw OAuthUsageError.missingFiveHour }
        let sevenDay = window(root["seven_day"])
        return SubscriptionDetail(
            fiveHourPercent: PercentMath.clamp(fiveHour.0),
            fiveHourResetsAt: fiveHour.1,
            sevenDayPercent: sevenDay.map { PercentMath.clamp($0.0) },
            sevenDayResetsAt: sevenDay?.1
        )
    }

    private static func window(_ value: Any?) -> (Double, Date?)? {
        guard let dict = value as? [String: Any], let utilization = doubleValue(dict["utilization"]) else { return nil }
        let resets = (dict["resets_at"] as? String).flatMap(ISODate.parse)
        return (utilization, resets)
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) }
        return nil
    }
}
