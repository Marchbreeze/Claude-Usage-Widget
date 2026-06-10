import Foundation

public enum ISODate {
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    public static func parse(_ s: String) -> Date? {
        plain.date(from: s) ?? fractional.date(from: s)
    }
    public static func string(from date: Date) -> String { plain.string(from: date) }
}
