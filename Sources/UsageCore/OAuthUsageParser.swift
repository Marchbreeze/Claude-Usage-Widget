import Foundation

public enum OAuthUsageError: Error, Equatable { case malformed, missingFiveHour }

public enum OAuthUsageParser {
    public static func parse(_ data: Data) throws -> SubscriptionDetail {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthUsageError.malformed
        }
        let fiveHour = window(root["five_hour"])
        let sevenDay = window(root["seven_day"])
        let extra = extraUsage(root["extra_usage"])
        // Subscription accounts expose five_hour; enterprise/extra-usage accounts have
        // all windows null but report pay-as-you-go spend in extra_usage. Require at least one.
        guard fiveHour != nil || extra != nil else { throw OAuthUsageError.missingFiveHour }
        return SubscriptionDetail(
            fiveHourPercent: fiveHour.map { PercentMath.clamp($0.0) },
            fiveHourResetsAt: fiveHour?.1,
            sevenDayPercent: sevenDay.map { PercentMath.clamp($0.0) },
            sevenDayResetsAt: sevenDay?.1,
            extraUsage: extra
        )
    }

    private static func extraUsage(_ value: Any?) -> ExtraUsage? {
        guard let dict = value as? [String: Any], (dict["is_enabled"] as? Bool) == true else { return nil }
        let used = doubleValue(dict["used_credits"])
        let limit = doubleValue(dict["monthly_limit"])
        // Prefer used/limit (the user-facing burn); fall back to the server's utilization field.
        let percent: Double?
        if let used, let limit { percent = PercentMath.budgetPercent(spend: used, budget: limit) }
        else { percent = doubleValue(dict["utilization"]).map(PercentMath.clamp) }
        guard let percent else { return nil }
        return ExtraUsage(percent: percent, usedUSD: used, limitUSD: limit)
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
