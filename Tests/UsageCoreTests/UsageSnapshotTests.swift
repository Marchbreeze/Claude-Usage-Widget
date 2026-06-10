import XCTest
@testable import UsageCore

final class UsageSnapshotTests: XCTestCase {
    func testRoundTripsThroughJSON() throws {
        let snap = UsageSnapshot(
            source: .subscription, percent: 73,
            subscription: SubscriptionDetail(fiveHourPercent: 73, fiveHourResetsAt: Date(timeIntervalSince1970: 1_750_000_000), sevenDayPercent: 41, sevenDayResetsAt: nil),
            api: nil, fetchedAt: Date(timeIntervalSince1970: 1_749_000_000))
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let back = try dec.decode(UsageSnapshot.self, from: try enc.encode(snap))
        XCTAssertEqual(back, snap)
    }
}
