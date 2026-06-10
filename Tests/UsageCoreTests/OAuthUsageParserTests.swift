import XCTest
@testable import UsageCore

final class OAuthUsageParserTests: XCTestCase {
    func testParsesGoodResponse() throws {
        let d = try OAuthUsageParser.parse(try fixture("oauth_usage_good"))
        XCTAssertEqual(d.fiveHourPercent, 73)
        XCTAssertEqual(d.sevenDayPercent, 41.5)
        XCTAssertNotNil(d.fiveHourResetsAt)
        XCTAssertNotNil(d.sevenDayResetsAt)
    }
    func testMissingFiveHourThrows() {
        XCTAssertThrowsError(try OAuthUsageParser.parse(try! fixture("oauth_usage_missing_five_hour")))
    }
    func testExtraFieldsToleratedAndClamped() throws {
        let d = try OAuthUsageParser.parse(try! fixture("oauth_usage_extra_fields"))
        XCTAssertEqual(d.fiveHourPercent, 100)
        XCTAssertNil(d.sevenDayPercent)
    }
    func testGarbageThrows() {
        XCTAssertThrowsError(try OAuthUsageParser.parse(Data("[]".utf8)))
    }
}
