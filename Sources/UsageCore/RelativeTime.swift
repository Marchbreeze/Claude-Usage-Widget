import Foundation

/// Korean "time remaining" formatting, with day units for spans over 24h.
public enum RelativeTime {
    /// e.g. "1일 10시간 후", "3시간 20분 후", "45분 후".
    /// Returns nil when `date` is not in the future relative to `now`.
    public static func until(_ date: Date, now: Date = Date()) -> String? {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return nil }
        let totalMinutes = Int(seconds / 60)
        let days = totalMinutes / 1440
        let hours = (totalMinutes % 1440) / 60
        let minutes = totalMinutes % 60
        if days >= 1 { return "\(days)일 \(hours)시간 후" }
        if hours >= 1 { return "\(hours)시간 \(minutes)분 후" }
        return "\(minutes)분 후"
    }
}

/// Monthly billing reset helpers (extra usage / monthly_limit resets at the
/// start of each calendar month, UTC).
public enum MonthlyReset {
    private static var utcCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// First instant (00:00 UTC) of the month after `now`.
    public static func startOfNextMonthUTC(after now: Date = Date()) -> Date {
        let cal = utcCalendar
        let comps = cal.dateComponents([.year, .month], from: now)
        let startOfThisMonth = cal.date(from: comps)!
        return cal.date(byAdding: .month, value: 1, to: startOfThisMonth)!
    }

    /// "M월 D일" for `date` interpreted in UTC.
    public static func monthDayUTC(_ date: Date) -> String {
        let c = utcCalendar.dateComponents([.month, .day], from: date)
        return "\(c.month!)월 \(c.day!)일"
    }
}
