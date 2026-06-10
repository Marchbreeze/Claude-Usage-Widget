import XCTest
@testable import UsageCore

final class MonthWindowTests: XCTestCase {
    func testStartOfMonth() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let mid = DateComponents(calendar: cal, year: 2026, month: 6, day: 15, hour: 13).date!
        let start = MonthWindow.start(of: mid, calendar: cal)
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: start)
        XCTAssertEqual([comps.year, comps.month, comps.day, comps.hour], [2026, 6, 1, 0])
    }
    func testRolloverProducesNewWindow() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let june30 = DateComponents(calendar: cal, year: 2026, month: 6, day: 30, hour: 23).date!
        let july1 = DateComponents(calendar: cal, year: 2026, month: 7, day: 1, hour: 1).date!
        XCTAssertNotEqual(MonthWindow.start(of: june30, calendar: cal), MonthWindow.start(of: july1, calendar: cal))
    }
}

final class ISODateTests: XCTestCase {
    func testParsesWithAndWithoutFractionalSeconds() {
        XCTAssertNotNil(ISODate.parse("2026-06-11T05:00:00Z"))
        XCTAssertNotNil(ISODate.parse("2026-06-11T05:00:00.123Z"))
        XCTAssertNil(ISODate.parse("not a date"))
    }
}
