import XCTest
@testable import UsageCore

final class PercentMathTests: XCTestCase {
    func testClamp() {
        XCTAssertEqual(PercentMath.clamp(-5), 0)
        XCTAssertEqual(PercentMath.clamp(50), 50)
        XCTAssertEqual(PercentMath.clamp(150), 100)
    }
    func testThresholdBoundary() {
        XCTAssertFalse(PercentMath.isOverThreshold(80.0))
        XCTAssertTrue(PercentMath.isOverThreshold(80.1))
        XCTAssertFalse(PercentMath.isOverThreshold(0))
        XCTAssertTrue(PercentMath.isOverThreshold(100))
    }
    func testBudgetPercent() {
        XCTAssertEqual(PercentMath.budgetPercent(spend: 100, budget: 200), 50)
        XCTAssertEqual(PercentMath.budgetPercent(spend: 500, budget: 200), 100)
        XCTAssertNil(PercentMath.budgetPercent(spend: 10, budget: 0))
        XCTAssertNil(PercentMath.budgetPercent(spend: 10, budget: -1))
    }
}
