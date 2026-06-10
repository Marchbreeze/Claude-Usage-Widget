import XCTest
@testable import UsageCore

final class CostReportParserTests: XCTestCase {
    func testParsesPageWithStringAmounts() throws {
        let page = try CostReportParser.parse(try fixture("cost_report_page1"))
        XCTAssertEqual(page.amountUSD, 13.0, accuracy: 0.0001)
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.nextPage, "page_xyz")
    }
    func testParsesPageWithNumericAmounts() throws {
        let page = try CostReportParser.parse(try fixture("cost_report_page2"))
        XCTAssertEqual(page.amountUSD, 7.0, accuracy: 0.0001)
        XCTAssertFalse(page.hasMore)
        XCTAssertNil(page.nextPage)
    }
    func testEmptyPage() throws {
        let page = try CostReportParser.parse(try fixture("cost_report_empty"))
        XCTAssertEqual(page.amountUSD, 0)
        XCTAssertFalse(page.hasMore)
    }
    func testGarbageThrows() {
        XCTAssertThrowsError(try CostReportParser.parse(Data("{}".utf8)))
    }
}
