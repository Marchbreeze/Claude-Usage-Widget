import Foundation

public enum CopilotUsageError: Error, Equatable { case malformed, missingQuota }

/// Parses the GitHub Copilot `/copilot_internal/user` response (the same payload
/// the IDE extensions read) into a `CopilotDetail`. The relevant figure is the
/// `premium_interactions` quota snapshot: how many premium requests remain of the
/// monthly entitlement. Display percent = used / entitlement.
public enum CopilotUsageParser {
    public static func parse(_ data: Data) throws -> CopilotDetail {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CopilotUsageError.malformed
        }
        let plan = root["copilot_plan"] as? String
        guard let snapshots = root["quota_snapshots"] as? [String: Any],
              let premium = snapshots["premium_interactions"] as? [String: Any] else {
            throw CopilotUsageError.missingQuota
        }

        let unlimited = (premium["unlimited"] as? Bool) ?? false
        let remaining = doubleValue(premium["remaining"])
        let entitlement = doubleValue(premium["entitlement"])
        let percentRemaining = doubleValue(premium["percent_remaining"])
        let overageCount = doubleValue(premium["overage_count"])
        let overageEntitlement = doubleValue(premium["overage_entitlement"])
        let overagePermitted = (premium["overage_permitted"] as? Bool) ?? false

        let usedPercent: Double
        if unlimited {
            usedPercent = 0
        } else if let entitlement, entitlement > 0, let remaining {
            usedPercent = PercentMath.clamp((entitlement - remaining) / entitlement * 100)
        } else if let percentRemaining {
            usedPercent = PercentMath.clamp(100 - percentRemaining)
        } else {
            usedPercent = 0
        }

        let resets = resetDate(root, snapshot: premium)
        return CopilotDetail(
            plan: plan,
            premiumPercent: usedPercent,
            remaining: remaining,
            entitlement: entitlement,
            unlimited: unlimited,
            overageCount: overageCount,
            overageEntitlement: overageEntitlement,
            overagePermitted: overagePermitted,
            resetsAt: resets
        )
    }

    /// Reset comes from a root `quota_reset_date` ("YYYY-MM-DD") or a snapshot
    /// `timestamp_utc`/`resets_at`; otherwise the start of next calendar month (UTC),
    /// since premium quotas reset on the 1st at 00:00 UTC.
    private static func resetDate(_ root: [String: Any], snapshot: [String: Any]) -> Date? {
        if let s = root["quota_reset_date"] as? String, let d = dateOnly(s) ?? ISODate.parse(s) {
            return d
        }
        if let s = snapshot["resets_at"] as? String, let d = ISODate.parse(s) ?? dateOnly(s) {
            return d
        }
        return MonthlyReset.startOfNextMonthUTC()
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dateOnly(_ s: String) -> Date? { dayFormatter.date(from: s) }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) }
        return nil
    }
}
