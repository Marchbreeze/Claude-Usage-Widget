import XCTest
@testable import UsageCore

final class RelativeTimeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    func testMinutesOnly() {
        XCTAssertEqual(RelativeTime.until(now.addingTimeInterval(45 * 60), now: now), "45분 후")
    }
    func testHoursAndMinutes() {
        XCTAssertEqual(RelativeTime.until(now.addingTimeInterval(3 * 3600 + 20 * 60), now: now), "3시간 20분 후")
    }
    func testDaysAndHours() {
        // 34h -> 1일 10시간 후
        XCTAssertEqual(RelativeTime.until(now.addingTimeInterval(34 * 3600), now: now), "1일 10시간 후")
    }
    func testExactlyOneDay() {
        XCTAssertEqual(RelativeTime.until(now.addingTimeInterval(24 * 3600), now: now), "1일 0시간 후")
    }
    func testPastReturnsNil() {
        XCTAssertNil(RelativeTime.until(now.addingTimeInterval(-60), now: now))
        XCTAssertNil(RelativeTime.until(now, now: now))
    }

    func testStartOfNextMonthIsFirstOfMonthUTC() {
        // 2026-06-15T... -> next reset 2026-07-01 00:00 UTC
        let jun15 = Date(timeIntervalSince1970: 1_781_000_000) // arbitrary; assert structurally instead
        let reset = MonthlyReset.startOfNextMonthUTC(after: jun15)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.day, .hour, .minute, .second], from: reset)
        XCTAssertEqual(c.day, 1)
        XCTAssertEqual(c.hour, 0)
        XCTAssertEqual(c.minute, 0)
        XCTAssertEqual(c.second, 0)
        XCTAssertGreaterThan(reset, jun15)
    }

    func testMonthDayFormatting() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        XCTAssertEqual(MonthlyReset.monthDayUTC(date), "7월 1일")
    }
}
