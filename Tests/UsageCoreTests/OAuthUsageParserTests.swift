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

    func testSubscriptionAccountWithExtraUsageDisabled() throws {
        let d = try OAuthUsageParser.parse(try fixture("oauth_usage_subscription"))
        XCTAssertEqual(d.fiveHourPercent, 0)
        XCTAssertEqual(d.sevenDayPercent, 9)
        XCTAssertNil(d.extraUsage) // is_enabled == false
    }

    func testEnterpriseAccountFallsBackToExtraUsage() throws {
        let d = try OAuthUsageParser.parse(try fixture("oauth_usage_enterprise"))
        XCTAssertNil(d.fiveHourPercent)        // five_hour is null
        XCTAssertNil(d.sevenDayPercent)        // seven_day is null
        let extra = try XCTUnwrap(d.extraUsage)
        XCTAssertEqual(extra.percent, 100)     // 20026/20000 clamped to 100
        XCTAssertEqual(extra.usedUSD, 20026)
        XCTAssertEqual(extra.limitUSD, 20000)
        // No server resets_at -> falls back to start of next calendar month (future).
        let reset = try XCTUnwrap(extra.resetsAt)
        XCTAssertGreaterThan(reset, Date())
    }

    func testAllNullWindowsAndNoExtraUsageThrows() {
        let json = #"{"five_hour": null, "seven_day": null, "extra_usage": {"is_enabled": false}}"#
        XCTAssertThrowsError(try OAuthUsageParser.parse(Data(json.utf8)))
    }
}
