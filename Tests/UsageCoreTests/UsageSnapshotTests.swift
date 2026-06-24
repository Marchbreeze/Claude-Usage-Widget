import XCTest
@testable import UsageCore

final class UsageSnapshotTests: XCTestCase {
    func testRoundTripsThroughJSON() throws {
        let snap = UsageSnapshot(
            percent: 73,
            subscription: SubscriptionDetail(fiveHourPercent: 73, fiveHourResetsAt: Date(timeIntervalSince1970: 1_750_000_000), sevenDayPercent: 41, sevenDayResetsAt: nil, extraUsage: ExtraUsage(percent: 100, usedUSD: 20026, limitUSD: 20000)),
            fetchedAt: Date(timeIntervalSince1970: 1_749_000_000))
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let back = try dec.decode(UsageSnapshot.self, from: try enc.encode(snap))
        XCTAssertEqual(back, snap)
    }

    func testDecodesLegacySnapshotWithoutProvider() throws {
        // Snapshots cached before Copilot support omit `provider`/`copilot`.
        let json = #"{"percent":73,"fetchedAt":1749000000}"#
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let snap = try dec.decode(UsageSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snap.percent, 73)
        XCTAssertEqual(snap.provider, .claude)
        XCTAssertNil(snap.copilot)
    }

    func testRoundTripsCopilotSnapshot() throws {
        let snap = UsageSnapshot(
            percent: 29.67,
            provider: .copilot,
            copilot: CopilotDetail(plan: "individual", premiumPercent: 29.67, remaining: 211, entitlement: 300, unlimited: false, overageCount: 0, overagePermitted: false, resetsAt: Date(timeIntervalSince1970: 1_751_328_000)),
            fetchedAt: Date(timeIntervalSince1970: 1_749_000_000))
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        let back = try dec.decode(UsageSnapshot.self, from: try enc.encode(snap))
        XCTAssertEqual(back, snap)
        XCTAssertEqual(back.provider, .copilot)
    }
}
