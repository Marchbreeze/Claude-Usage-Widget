import XCTest
@testable import UsageCore

final class CopilotUsageParserTests: XCTestCase {
    func testParsesPremiumInteractions() throws {
        let d = try CopilotUsageParser.parse(try fixture("copilot_user_good"))
        XCTAssertEqual(d.plan, "individual")
        XCTAssertFalse(d.unlimited)
        XCTAssertEqual(d.entitlement, 300)
        XCTAssertEqual(d.remaining, 211)
        // 300 - 211 = 89 used -> 29.67%
        XCTAssertEqual(d.premiumPercent, 89.0 / 300.0 * 100, accuracy: 0.001)
        XCTAssertNotNil(d.resetsAt)
    }

    func testUnlimitedPlanIsZeroPercent() throws {
        let d = try CopilotUsageParser.parse(try fixture("copilot_user_unlimited"))
        XCTAssertTrue(d.unlimited)
        XCTAssertEqual(d.premiumPercent, 0)
    }

    func testOverThresholdWithOverage() throws {
        let d = try CopilotUsageParser.parse(try fixture("copilot_user_over"))
        // 300 - 12 = 288 used -> 96%
        XCTAssertEqual(d.premiumPercent, 96, accuracy: 0.001)
        XCTAssertTrue(PercentMath.isOverThreshold(d.premiumPercent))
        XCTAssertEqual(d.overageCount, 5)
        XCTAssertTrue(d.overagePermitted)
        XCTAssertNotNil(d.resetsAt)
    }

    func testExhaustedQuotaClampsTo100AndParsesOverageEntitlement() throws {
        let d = try CopilotUsageParser.parse(try fixture("copilot_user_exhausted_overage"))
        // remaining is negative -> used clamps to 100%
        XCTAssertEqual(d.premiumPercent, 100, accuracy: 0.001)
        XCTAssertEqual(d.remaining, -18)
        XCTAssertEqual(d.overageCount, 17)
        XCTAssertEqual(d.overageEntitlement, 1000)
        XCTAssertTrue(d.overagePermitted)
        // The parser leaves dollar fields to the provider.
        XCTAssertNil(d.overageSpendUSD)
        XCTAssertFalse(d.isInOverage)
    }

    func testMissingPremiumQuotaThrows() {
        XCTAssertThrowsError(try CopilotUsageParser.parse(try! fixture("copilot_user_no_quota"))) { error in
            XCTAssertEqual(error as? CopilotUsageError, .missingQuota)
        }
    }

    func testGarbageThrows() {
        XCTAssertThrowsError(try CopilotUsageParser.parse(Data("[]".utf8)))
    }
}
