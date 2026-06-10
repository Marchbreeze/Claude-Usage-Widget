import XCTest
@testable import UsageCore

final class ISODateTests: XCTestCase {
    func testParsesWithAndWithoutFractionalSeconds() {
        XCTAssertNotNil(ISODate.parse("2026-06-11T05:00:00Z"))
        XCTAssertNotNil(ISODate.parse("2026-06-11T05:00:00.123Z"))
        XCTAssertNil(ISODate.parse("not a date"))
    }
}
