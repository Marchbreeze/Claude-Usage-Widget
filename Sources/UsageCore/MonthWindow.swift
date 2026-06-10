import Foundation

public enum MonthWindow {
    public static func start(of date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
