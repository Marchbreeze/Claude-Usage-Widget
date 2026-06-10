# Claude Usage Widget Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS menu bar app showing Claude usage % (subscription 5-hour session, or API spend vs monthly budget) as orange icon + progress bar + percent, red above 80%, distributed unsigned via GitHub Releases.

**Architecture:** SwiftPM package with a pure-Foundation `UsageCore` library (parsers + math, fully unit-tested) and a thin AppKit/SwiftUI executable `ClaudeUsageWidget` (NSStatusItem, providers, settings). CI on GitHub Actions runs `swift test` on every push and assembles/zips the .app on `v*` tags.

**Tech Stack:** Swift 5.9+, SwiftPM, AppKit + SwiftUI (macOS 13+), XCTest, GitHub Actions (macos-latest).

**Spec:** `docs/superpowers/specs/2026-06-11-claude-usage-widget-design.md`

**⚠ Environment adaptation:** The implementing agent's sandbox is Linux and cannot run `swift`. TDD is preserved at the task level (tests are written before/with implementation and committed together), but *test execution* happens per-chunk on GitHub Actions (macos-latest) instead of per-step locally. Every chunk ends with: push → confirm CI green → fix-and-repush loop. If the user runs locally, `swift test` at each marked verification point is equivalent.

## File structure

```
Package.swift
Sources/UsageCore/UsageSnapshot.swift        — data models (snapshot, details)
Sources/UsageCore/PercentMath.swift          — clamp, budget %, 80% threshold
Sources/UsageCore/MonthWindow.swift          — start-of-month calc
Sources/UsageCore/ISODate.swift              — tolerant ISO8601 parsing
Sources/UsageCore/CredentialsParser.swift    — Claude Code keychain JSON → token
Sources/UsageCore/OAuthUsageParser.swift     — /api/oauth/usage JSON → SubscriptionDetail
Sources/UsageCore/CostReportParser.swift     — /v1/organizations/cost_report JSON → page sum
Sources/ClaudeUsageWidget/main.swift         — app entry, AppDelegate
Sources/ClaudeUsageWidget/UsageProvider.swift— provider protocol + FetchError
Sources/ClaudeUsageWidget/KeychainReader.swift
Sources/ClaudeUsageWidget/SubscriptionProvider.swift
Sources/ClaudeUsageWidget/APICostProvider.swift
Sources/ClaudeUsageWidget/SettingsStore.swift
Sources/ClaudeUsageWidget/SnapshotCache.swift
Sources/ClaudeUsageWidget/ClaudeIconView.swift
Sources/ClaudeUsageWidget/StatusBarView.swift
Sources/ClaudeUsageWidget/StatusItemController.swift
Sources/ClaudeUsageWidget/SettingsWindow.swift
Tests/UsageCoreTests/…Tests.swift (one per UsageCore file)
Tests/UsageCoreTests/Fixtures/*.json
Resources/Info.plist
assets/AppIcon.png.b64
scripts/make_app.sh
.github/workflows/ci.yml
README.md
.gitignore
```

---

## Chunk 1: Scaffolding, models, PercentMath, MonthWindow

### Task 1: Package scaffolding

**Files:** Create `Package.swift`, `.gitignore`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "UsageCore"),
        .executableTarget(name: "ClaudeUsageWidget", dependencies: ["UsageCore"]),
        .testTarget(name: "UsageCoreTests", dependencies: ["UsageCore"]),
    ]
)
```

(The `resources: [.copy("Fixtures")]` line is added in Chunk 2 Task 6 together with the fixture files — declaring a missing resource directory makes SwiftPM hard-error.)

- [ ] **Step 2: Write `.gitignore`**

```
.build/
build/
.DS_Store
*.xcodeproj
```

- [ ] **Step 3: Commit**

```bash
git add Package.swift .gitignore && git commit -m "chore: SwiftPM package scaffolding"
```

### Task 2: Models (`UsageSnapshot`)

**Files:** Create `Sources/UsageCore/UsageSnapshot.swift`, `Tests/UsageCoreTests/UsageSnapshotTests.swift`

- [ ] **Step 1: Write the test**

```swift
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
```

- [ ] **Step 2: Write the implementation**

```swift
import Foundation

public struct SubscriptionDetail: Codable, Equatable {
    public let fiveHourPercent: Double
    public let fiveHourResetsAt: Date?
    public let sevenDayPercent: Double?
    public let sevenDayResetsAt: Date?
    public init(fiveHourPercent: Double, fiveHourResetsAt: Date?, sevenDayPercent: Double?, sevenDayResetsAt: Date?) {
        self.fiveHourPercent = fiveHourPercent
        self.fiveHourResetsAt = fiveHourResetsAt
        self.sevenDayPercent = sevenDayPercent
        self.sevenDayResetsAt = sevenDayResetsAt
    }
}

public struct APIDetail: Codable, Equatable {
    public let spendUSD: Double
    public let budgetUSD: Double
    public init(spendUSD: Double, budgetUSD: Double) {
        self.spendUSD = spendUSD
        self.budgetUSD = budgetUSD
    }
}

public struct UsageSnapshot: Codable, Equatable {
    public enum Source: String, Codable { case subscription, api }
    public let source: Source
    public let percent: Double
    public let subscription: SubscriptionDetail?
    public let api: APIDetail?
    public let fetchedAt: Date
    public init(source: Source, percent: Double, subscription: SubscriptionDetail?, api: APIDetail?, fetchedAt: Date) {
        self.source = source
        self.percent = percent
        self.subscription = subscription
        self.api = api
        self.fetchedAt = fetchedAt
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/UsageCore/UsageSnapshot.swift Tests/UsageCoreTests/UsageSnapshotTests.swift
git commit -m "feat(core): usage snapshot models"
```

### Task 3: PercentMath

**Files:** Create `Sources/UsageCore/PercentMath.swift`, `Tests/UsageCoreTests/PercentMathTests.swift`

- [ ] **Step 1: Write the tests** (threshold boundary per spec: 80.0 → orange, 80.1 → red; budget ≤ 0 guarded)

```swift
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
```

- [ ] **Step 2: Write the implementation**

```swift
import Foundation

public enum PercentMath {
    public static func clamp(_ p: Double) -> Double { min(100, max(0, p)) }
    public static func budgetPercent(spend: Double, budget: Double) -> Double? {
        guard budget > 0 else { return nil }
        return clamp(spend / budget * 100)
    }
    public static func isOverThreshold(_ percent: Double) -> Bool { percent > 80 }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/UsageCore/PercentMath.swift Tests/UsageCoreTests/PercentMathTests.swift
git commit -m "feat(core): percent math with 80% threshold"
```

### Task 4: MonthWindow + ISODate

**Files:** Create `Sources/UsageCore/MonthWindow.swift`, `Sources/UsageCore/ISODate.swift`, `Tests/UsageCoreTests/MonthWindowTests.swift`, `Tests/UsageCoreTests/ISODateTests.swift`

- [ ] **Step 1: Write the tests**

```swift
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
```

- [ ] **Step 2: Write the implementations**

`MonthWindow.swift`:
```swift
import Foundation

public enum MonthWindow {
    public static func start(of date: Date = Date(), calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}
```

`ISODate.swift`:
```swift
import Foundation

public enum ISODate {
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    public static func parse(_ s: String) -> Date? {
        plain.date(from: s) ?? fractional.date(from: s)
    }
    public static func string(from date: Date) -> String { plain.string(from: date) }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/UsageCore/MonthWindow.swift Sources/UsageCore/ISODate.swift Tests/UsageCoreTests/MonthWindowTests.swift Tests/UsageCoreTests/ISODateTests.swift
git commit -m "feat(core): month window and tolerant ISO8601 parsing"
```

### Task 5: GitHub repo + CI workflow + Chunk 1 verification

**Files:** Create `.github/workflows/ci.yml`

- [ ] **Step 1:** Create public GitHub repo `Claude-Usage-Widget` via GitHub MCP `create_repository`.
- [ ] **Step 2:** Write `.github/workflows/ci.yml`:

```yaml
name: CI
on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - run: swift build
      - run: swift test

  release:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: test
    runs-on: macos-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/make_app.sh
      - uses: softprops/action-gh-release@v2
        with:
          files: build/ClaudeUsageWidget.zip
          generate_release_notes: true
```

(`bash scripts/make_app.sh` — not `./` — because mirroring files via GitHub MCP loses the executable bit. The release job will fail on tags until Chunk 4 adds `scripts/make_app.sh`; only the `test` job gates Chunks 1–3.)

- [ ] **Step 3:** Commit: `git add .github/workflows/ci.yml && git commit -m "ci: swift test on push, release on v* tags"`
- [ ] **Step 4:** Mirror all commits so far to GitHub via MCP `push_files` (local repo is source of truth).
- [ ] **Step 5:** Confirm `test` job green (poll `https://api.github.com/repos/<owner>/Claude-Usage-Widget/actions/runs?per_page=1` via web_fetch). If red: read log, fix, commit, re-mirror, repeat.

---

## Chunk 2: Parsers + fixtures

### Task 6: Test fixtures

**Files:** Create under `Tests/UsageCoreTests/Fixtures/`

- [ ] **Step 0: Declare the resource in `Package.swift`** — change the test target to:

```swift
        .testTarget(
            name: "UsageCoreTests",
            dependencies: ["UsageCore"],
            resources: [.copy("Fixtures")]
        ),
```

- [ ] **Step 1: Write all fixture JSON files**

`credentials_good.json`:
```json
{"claudeAiOauth": {"accessToken": "sk-ant-oat01-TESTTOKEN", "refreshToken": "rt", "expiresAt": 99999999999999, "scopes": ["user:inference"], "subscriptionType": "enterprise"}}
```

`credentials_missing_token.json`:
```json
{"claudeAiOauth": {"refreshToken": "rt", "expiresAt": 99999999999999}}
```

`oauth_usage_good.json`:
```json
{"five_hour": {"utilization": 73, "resets_at": "2026-06-11T05:00:00Z"}, "seven_day": {"utilization": 41.5, "resets_at": "2026-06-15T00:00:00Z"}}
```

`oauth_usage_missing_five_hour.json`:
```json
{"seven_day": {"utilization": 41.5, "resets_at": "2026-06-15T00:00:00Z"}}
```

`oauth_usage_extra_fields.json`:
```json
{"five_hour": {"utilization": 120, "resets_at": "2026-06-11T05:00:00.500Z", "new_field": {"a": 1}}, "seven_day": null, "seven_day_opus": {"utilization": 5}, "extra_top": true}
```

`cost_report_page1.json`:
```json
{"data": [{"starting_at": "2026-06-01T00:00:00Z", "ending_at": "2026-06-02T00:00:00Z", "results": [{"currency": "USD", "amount": "12.34"}, {"currency": "USD", "amount": "0.66"}]}], "has_more": true, "next_page": "page_xyz"}
```

`cost_report_page2.json`:
```json
{"data": [{"starting_at": "2026-06-02T00:00:00Z", "ending_at": "2026-06-03T00:00:00Z", "results": [{"currency": "USD", "amount": 7.0}]}], "has_more": false, "next_page": null}
```

`cost_report_empty.json`:
```json
{"data": [], "has_more": false, "next_page": null}
```

- [ ] **Step 2:** Add a shared fixture loader `Tests/UsageCoreTests/FixtureLoader.swift`:

```swift
import Foundation
import XCTest

func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"))
    return try Data(contentsOf: url)
}
```

- [ ] **Step 3: Commit**

```bash
git add Package.swift Tests/UsageCoreTests/Fixtures Tests/UsageCoreTests/FixtureLoader.swift
git commit -m "test(core): parser fixtures"
```

### Task 7: CredentialsParser

**Files:** Create `Sources/UsageCore/CredentialsParser.swift`, `Tests/UsageCoreTests/CredentialsParserTests.swift`

- [ ] **Step 1: Write the tests**

```swift
import XCTest
@testable import UsageCore

final class CredentialsParserTests: XCTestCase {
    func testParsesToken() throws {
        let creds = try CredentialsParser.parse(try fixture("credentials_good"))
        XCTAssertEqual(creds.accessToken, "sk-ant-oat01-TESTTOKEN")
        XCTAssertFalse(creds.isExpired(now: Date()))
    }
    func testMissingTokenThrows() {
        XCTAssertThrowsError(try CredentialsParser.parse(try! fixture("credentials_missing_token")))
    }
    func testGarbageThrows() {
        XCTAssertThrowsError(try CredentialsParser.parse(Data("not json".utf8)))
    }
    func testExpiry() throws {
        let creds = ClaudeCredentials(accessToken: "t", expiresAt: Date(timeIntervalSince1970: 1000))
        XCTAssertTrue(creds.isExpired(now: Date(timeIntervalSince1970: 2000)))
        XCTAssertFalse(creds.isExpired(now: Date(timeIntervalSince1970: 500)))
    }
}
```

- [ ] **Step 2: Write the implementation**

```swift
import Foundation

public struct ClaudeCredentials: Equatable {
    public let accessToken: String
    public let expiresAt: Date?
    public init(accessToken: String, expiresAt: Date?) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
    }
    public func isExpired(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }
}

public enum CredentialsError: Error, Equatable { case malformed, missingToken }

public enum CredentialsParser {
    public static func parse(_ data: Data) throws -> ClaudeCredentials {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CredentialsError.malformed
        }
        let oauth = (root["claudeAiOauth"] as? [String: Any]) ?? root
        guard let token = oauth["accessToken"] as? String, !token.isEmpty else {
            throw CredentialsError.missingToken
        }
        var expires: Date?
        if let ms = oauth["expiresAt"] as? Double, ms > 0 {
            expires = Date(timeIntervalSince1970: ms / 1000)
        }
        return ClaudeCredentials(accessToken: token, expiresAt: expires)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/UsageCore/CredentialsParser.swift Tests/UsageCoreTests/CredentialsParserTests.swift
git commit -m "feat(core): Claude Code credentials parser"
```

### Task 8: OAuthUsageParser

**Files:** Create `Sources/UsageCore/OAuthUsageParser.swift`, `Tests/UsageCoreTests/OAuthUsageParserTests.swift`

- [ ] **Step 1: Write the tests**

```swift
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
```

- [ ] **Step 2: Write the implementation**

```swift
import Foundation

public enum OAuthUsageError: Error, Equatable { case malformed, missingFiveHour }

public enum OAuthUsageParser {
    public static func parse(_ data: Data) throws -> SubscriptionDetail {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OAuthUsageError.malformed
        }
        guard let fiveHour = window(root["five_hour"]) else { throw OAuthUsageError.missingFiveHour }
        let sevenDay = window(root["seven_day"])
        return SubscriptionDetail(
            fiveHourPercent: PercentMath.clamp(fiveHour.0),
            fiveHourResetsAt: fiveHour.1,
            sevenDayPercent: sevenDay.map { PercentMath.clamp($0.0) },
            sevenDayResetsAt: sevenDay?.1
        )
    }

    private static func window(_ value: Any?) -> (Double, Date?)? {
        guard let dict = value as? [String: Any], let utilization = doubleValue(dict["utilization"]) else { return nil }
        let resets = (dict["resets_at"] as? String).flatMap(ISODate.parse)
        return (utilization, resets)
    }

    private static func doubleValue(_ any: Any?) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let s = any as? String { return Double(s) }
        return nil
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/UsageCore/OAuthUsageParser.swift Tests/UsageCoreTests/OAuthUsageParserTests.swift
git commit -m "feat(core): oauth usage parser (5h/7d windows)"
```

### Task 9: CostReportParser

**Files:** Create `Sources/UsageCore/CostReportParser.swift`, `Tests/UsageCoreTests/CostReportParserTests.swift`

- [ ] **Step 1: Write the tests**

```swift
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
```

- [ ] **Step 2: Write the implementation**

```swift
import Foundation

public struct CostPage: Equatable {
    public let amountUSD: Double
    public let hasMore: Bool
    public let nextPage: String?
    public init(amountUSD: Double, hasMore: Bool, nextPage: String?) {
        self.amountUSD = amountUSD
        self.hasMore = hasMore
        self.nextPage = nextPage
    }
}

public enum CostReportError: Error, Equatable { case malformed }

public enum CostReportParser {
    public static func parse(_ data: Data) throws -> CostPage {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buckets = root["data"] as? [[String: Any]] else {
            throw CostReportError.malformed
        }
        var total = 0.0
        for bucket in buckets {
            for result in (bucket["results"] as? [[String: Any]]) ?? [] {
                if let s = result["amount"] as? String, let v = Double(s) { total += v }
                else if let v = result["amount"] as? Double { total += v }
            }
        }
        return CostPage(
            amountUSD: total,
            hasMore: root["has_more"] as? Bool ?? false,
            nextPage: root["next_page"] as? String
        )
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/UsageCore/CostReportParser.swift Tests/UsageCoreTests/CostReportParserTests.swift
git commit -m "feat(core): cost report parser with pagination fields"
```

### Task 10: Chunk 2 CI verification

- [ ] **Step 1:** Push to GitHub, confirm `swift test` green; fix-and-repush until green.

---

## Chunk 3: App layer

All files in this chunk are AppKit/SwiftUI glue (not unit-tested per spec); verification is that the executable *compiles* on CI (`swift build` is implied by `swift test`) plus manual smoke test by the user at the end.

### Task 11: Provider protocol, KeychainReader, providers

**Files:** Create `Sources/ClaudeUsageWidget/UsageProvider.swift`, `KeychainReader.swift`, `SubscriptionProvider.swift`, `APICostProvider.swift`

- [ ] **Step 1: `UsageProvider.swift`**

```swift
import Foundation
import UsageCore

enum FetchError: Error, Equatable {
    case needsClaudeLogin
    case needsAPIKey
    case invalidAPIKey
    case needsBudget
    case network(String)

    var userMessage: String {
        switch self {
        case .needsClaudeLogin: return "Claude Code 로그인이 필요합니다 (터미널에서 claude 실행)"
        case .needsAPIKey: return "설정에서 Admin API 키를 입력하세요"
        case .invalidAPIKey: return "API 키가 올바르지 않습니다"
        case .needsBudget: return "설정에서 월 예산을 입력하세요"
        case .network(let detail): return "네트워크 오류: \(detail)"
        }
    }
}

protocol UsageProvider {
    var pollInterval: TimeInterval { get }
    func fetch() async throws -> UsageSnapshot
}
```

- [ ] **Step 2: `KeychainReader.swift`**

```swift
import Foundation
import Security

enum KeychainError: Error { case notFound, unreadable }

enum KeychainReader {
    static func read(service: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw status == errSecItemNotFound ? KeychainError.notFound : KeychainError.unreadable
        }
        return data
    }

    static func write(service: String, data: Data) {
        delete(service: service)
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
        ]
        SecItemAdd(attrs as CFDictionary, nil)
    }

    static func delete(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 3: `SubscriptionProvider.swift`**

```swift
import Foundation
import UsageCore

struct SubscriptionProvider: UsageProvider {
    let pollInterval: TimeInterval = 60
    static let credentialsService = "Claude Code-credentials"

    func fetch() async throws -> UsageSnapshot {
        let credData: Data
        do { credData = try KeychainReader.read(service: Self.credentialsService) }
        catch { throw FetchError.needsClaudeLogin }
        guard let creds = try? CredentialsParser.parse(credData), !creds.isExpired() else {
            throw FetchError.needsClaudeLogin
        }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(creds.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw FetchError.network("응답 없음") }
        if http.statusCode == 401 || http.statusCode == 403 { throw FetchError.needsClaudeLogin }
        guard http.statusCode == 200 else { throw FetchError.network("HTTP \(http.statusCode)") }
        guard let detail = try? OAuthUsageParser.parse(data) else { throw FetchError.network("응답 형식 오류") }
        return UsageSnapshot(source: .subscription, percent: detail.fiveHourPercent,
                             subscription: detail, api: nil, fetchedAt: Date())
    }
}
```

- [ ] **Step 4: `APICostProvider.swift`**

```swift
import Foundation
import UsageCore

struct APICostProvider: UsageProvider {
    let settings: SettingsStore
    let pollInterval: TimeInterval = 300

    func fetch() async throws -> UsageSnapshot {
        guard let key = settings.adminAPIKey, !key.isEmpty else { throw FetchError.needsAPIKey }
        let budget = settings.monthlyBudgetUSD
        guard budget > 0 else { throw FetchError.needsBudget }

        var total = 0.0
        var page: String?
        var pageCount = 0
        repeat {
            var comps = URLComponents(string: "https://api.anthropic.com/v1/organizations/cost_report")!
            var items = [
                URLQueryItem(name: "starting_at", value: ISODate.string(from: MonthWindow.start())),
                URLQueryItem(name: "limit", value: "31"),
            ]
            if let page { items.append(URLQueryItem(name: "page", value: page)) }
            comps.queryItems = items
            var req = URLRequest(url: comps.url!)
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw FetchError.network("응답 없음") }
            if http.statusCode == 401 || http.statusCode == 403 { throw FetchError.invalidAPIKey }
            guard http.statusCode == 200 else { throw FetchError.network("HTTP \(http.statusCode)") }
            guard let parsed = try? CostReportParser.parse(data) else { throw FetchError.network("응답 형식 오류") }
            total += parsed.amountUSD
            page = parsed.hasMore ? parsed.nextPage : nil
            pageCount += 1
        } while page != nil && pageCount < 24

        let percent = PercentMath.budgetPercent(spend: total, budget: budget) ?? 0
        return UsageSnapshot(source: .api, percent: percent, subscription: nil,
                             api: APIDetail(spendUSD: total, budgetUSD: budget), fetchedAt: Date())
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add Sources/ClaudeUsageWidget/UsageProvider.swift Sources/ClaudeUsageWidget/KeychainReader.swift Sources/ClaudeUsageWidget/SubscriptionProvider.swift Sources/ClaudeUsageWidget/APICostProvider.swift
git commit -m "feat(app): usage providers (subscription oauth + api cost)"
```

### Task 12: SettingsStore + SnapshotCache

**Files:** Create `Sources/ClaudeUsageWidget/SettingsStore.swift`, `Sources/ClaudeUsageWidget/SnapshotCache.swift`

- [ ] **Step 1: `SettingsStore.swift`**

```swift
import Foundation
import ServiceManagement

final class SettingsStore: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case subscription, api
        var id: String { rawValue }
        var label: String { self == .subscription ? "구독 (Claude Code)" : "API (Admin 키)" }
    }

    private static let apiKeyService = "ClaudeUsageWidget-admin-key"
    private let defaults = UserDefaults.standard

    @Published var mode: Mode {
        didSet { defaults.set(mode.rawValue, forKey: "mode") }
    }
    @Published var monthlyBudgetUSD: Double {
        didSet { defaults.set(monthlyBudgetUSD, forKey: "monthlyBudgetUSD") }
    }
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin() }
    }

    var adminAPIKey: String? {
        get { (try? KeychainReader.read(service: Self.apiKeyService)).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let newValue, !newValue.isEmpty {
                KeychainReader.write(service: Self.apiKeyService, data: Data(newValue.utf8))
            } else {
                KeychainReader.delete(service: Self.apiKeyService)
            }
            objectWillChange.send()
        }
    }

    init() {
        mode = Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .subscription
        let budget = defaults.object(forKey: "monthlyBudgetUSD") as? Double
        monthlyBudgetUSD = budget ?? 200
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("launch-at-login failed: \(error)")
        }
    }
}
```

- [ ] **Step 2: `SnapshotCache.swift`**

```swift
import Foundation
import UsageCore

enum SnapshotCache {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeUsageWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last-snapshot.json")
    }

    static func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode(UsageSnapshot.self, from: data)
    }

    static func save(_ snapshot: UsageSnapshot) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        guard let data = try? enc.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeUsageWidget/SettingsStore.swift Sources/ClaudeUsageWidget/SnapshotCache.swift
git commit -m "feat(app): settings store and snapshot cache"
```

### Task 13: Menu bar UI (icon, bar, percent)

**Files:** Create `Sources/ClaudeUsageWidget/ClaudeIconView.swift`, `Sources/ClaudeUsageWidget/StatusBarView.swift`

- [ ] **Step 1: `ClaudeIconView.swift`** — vector "sunburst" Claude character (12 rounded rays around a center), tinted by state color:

```swift
import SwiftUI

struct ClaudeIconView: View {
    let color: Color
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2
            let inner = outer * 0.38
            let rayWidth = outer * 0.26
            for i in 0..<12 {
                let angle = Double(i) * .pi / 6
                var path = Path()
                let from = CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
                let to = CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
                path.move(to: from)
                path.addLine(to: to)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: rayWidth, lineCap: .round))
            }
        }
        .accessibilityLabel("Claude usage")
    }
}
```

- [ ] **Step 2: `StatusBarView.swift`**

```swift
import SwiftUI
import UsageCore

struct StatusBarModel {
    var percent: Double?
    var isStale: Bool = false
}

struct StatusBarView: View {
    let model: StatusBarModel

    private var color: Color {
        guard let p = model.percent else { return .gray }
        if PercentMath.isOverThreshold(p) { return Color(red: 0.898, green: 0.282, blue: 0.302) }
        return Color(red: 0.851, green: 0.467, blue: 0.341)
    }

    var body: some View {
        HStack(spacing: 5) {
            ClaudeIconView(color: color).frame(width: 15, height: 15)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.25))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * CGFloat((model.percent ?? 0) / 100))
                }
            }
            .frame(width: 36, height: 6)
            Text(model.percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundColor(color)
                .opacity(model.isStale ? 0.55 : 1)
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
    }
}
```

(Orange `#D97757` = 217/119/87; red `#E5484D` = 229/72/77. Gray + `—` when no data, per spec.)

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeUsageWidget/ClaudeIconView.swift Sources/ClaudeUsageWidget/StatusBarView.swift
git commit -m "feat(app): menu bar view (icon + progress bar + percent)"
```

### Task 14: StatusItemController + dropdown menu + polling

**Files:** Create `Sources/ClaudeUsageWidget/StatusItemController.swift`

- [ ] **Step 1: Write the controller**

```swift
import AppKit
import SwiftUI
import UsageCore

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let hosting: NSHostingView<StatusBarView>
    private let settings: SettingsStore
    private let menu = NSMenu()

    private var snapshot: UsageSnapshot?
    private var lastError: FetchError?
    private var consecutiveFailures = 0
    private var pollTask: Task<Void, Never>?
    private var settingsWindow: SettingsWindowController?

    init(settings: SettingsStore) {
        self.settings = settings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let restored = SnapshotCache.load()
        snapshot = restored
        hosting = NSHostingView(rootView: StatusBarView(model: StatusBarModel(percent: restored?.percent, isStale: restored != nil)))
        hosting.frame = NSRect(x: 0, y: 0, width: 86, height: 22)
        super.init()
        statusItem.button?.addSubview(hosting)
        statusItem.button?.frame = hosting.frame
        statusItem.length = hosting.frame.width
        menu.delegate = self
        statusItem.menu = menu
        startPolling()
    }

    func restartPolling() {
        pollTask?.cancel()
        consecutiveFailures = 0
        startPolling()
    }

    private var provider: UsageProvider {
        settings.mode == .subscription ? SubscriptionProvider() : APICostProvider(settings: settings)
    }

    private func startPolling() {
        pollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.tick()
                let base = self.provider.pollInterval
                let delay = self.consecutiveFailures == 0
                    ? base
                    : min(base * pow(2, Double(self.consecutiveFailures)), 900)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func tick() async {
        do {
            let snap = try await provider.fetch()
            snapshot = snap
            lastError = nil
            consecutiveFailures = 0
            SnapshotCache.save(snap)
            render(percent: snap.percent, isStale: false)
        } catch {
            lastError = error as? FetchError ?? .network("\(error)")
            consecutiveFailures += 1
            switch lastError! {
            case .network:
                render(percent: snapshot?.percent, isStale: true)
            default:
                render(percent: nil, isStale: false)
            }
        }
    }

    private func render(percent: Double?, isStale: Bool) {
        hosting.rootView = StatusBarView(model: StatusBarModel(percent: percent, isStale: isStale))
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let snap = snapshot {
            if let sub = snap.subscription {
                menu.addItem(label: "5시간 세션: \(Int(sub.fiveHourPercent.rounded()))% 사용" + countdown(sub.fiveHourResetsAt))
                if let weekly = sub.sevenDayPercent {
                    menu.addItem(label: "주간: \(Int(weekly.rounded()))% 사용" + countdown(sub.sevenDayResetsAt))
                }
            }
            if let api = snap.api {
                menu.addItem(label: String(format: "이번 달 지출: $%.2f / $%.0f", api.spendUSD, api.budgetUSD))
            }
            let age = Int(Date().timeIntervalSince(snap.fetchedAt) / 60)
            if age >= 2 || lastError != nil {
                menu.addItem(label: "마지막 갱신 \(max(age, 1))분 전")
            }
        }
        if let err = lastError {
            menu.addItem(label: "⚠ " + err.userMessage)
        }
        if snapshot == nil && lastError == nil {
            menu.addItem(label: "불러오는 중…")
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "지금 새로고침", action: #selector(refreshNow), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "설정…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func countdown(_ date: Date?) -> String {
        guard let date, date > Date() else { return "" }
        let mins = Int(date.timeIntervalSinceNow / 60)
        return mins >= 60 ? " · 리셋 \(mins / 60)시간 \(mins % 60)분 후" : " · 리셋 \(mins)분 후"
    }

    @objc private func refreshNow() { Task { await tick() } }

    @objc private func openSettings() {
        if settingsWindow == nil { settingsWindow = SettingsWindowController(settings: settings, onChange: { [weak self] in self?.restartPolling() }) }
        settingsWindow?.show()
    }
}

private extension NSMenu {
    func addItem(label: String) {
        let item = NSMenuItem(title: label, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add Sources/ClaudeUsageWidget/StatusItemController.swift
git commit -m "feat(app): status item controller with polling, backoff, dropdown"
```

### Task 15: Settings window + app entry

**Files:** Create `Sources/ClaudeUsageWidget/SettingsWindow.swift`, `Sources/ClaudeUsageWidget/main.swift`

- [ ] **Step 1: `SettingsWindow.swift`**

```swift
import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var apiKey: String = ""
    @State private var budgetText: String = ""
    let onChange: () -> Void

    var body: some View {
        Form {
            Picker("표시할 사용량", selection: $settings.mode) {
                ForEach(SettingsStore.Mode.allCases) { Text($0.label).tag($0) }
            }
            .onChange(of: settings.mode) { _ in onChange() }

            if settings.mode == .api {
                SecureField("Admin API 키 (sk-ant-admin…)", text: $apiKey)
                TextField("월 예산 (USD)", text: $budgetText)
                Button("저장") {
                    if !apiKey.isEmpty { settings.adminAPIKey = apiKey }
                    if let budget = Double(budgetText), budget > 0 { settings.monthlyBudgetUSD = budget }
                    onChange()
                }
            } else {
                Text("Claude Code가 로그인되어 있으면 자동으로 동작합니다.")
                    .font(.caption).foregroundColor(.secondary)
            }

            Toggle("로그인 시 자동 실행", isOn: $settings.launchAtLogin)
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            apiKey = settings.adminAPIKey ?? ""
            budgetText = String(format: "%.0f", settings.monthlyBudgetUSD)
        }
    }
}

@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(settings: SettingsStore, onChange: @escaping () -> Void) {
        let hosting = NSHostingController(rootView: SettingsView(settings: settings, onChange: onChange))
        window = NSWindow(contentViewController: hosting)
        window.title = "Claude Usage Widget 설정"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
    }

    func show() {
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 2: `main.swift`**

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?
    private let settings = SettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController(settings: settings)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [ ] **Step 3: Commit**

```bash
git add Sources/ClaudeUsageWidget/SettingsWindow.swift Sources/ClaudeUsageWidget/main.swift
git commit -m "feat(app): settings window and app entry"
```

- [ ] **Step 4: Chunk 3 verification** — mirror commits to GitHub, confirm `test` job green (the workflow from Task 5 compiles the whole package, including the executable). Fix-and-repush until green.

---

## Chunk 4: Packaging, CI, README, release

### Task 16: GitHub repo

Repo creation + mirroring method moved to Chunk 1 Task 5.

- [ ] **Step 1:** Verify the repo exists and `main` on GitHub matches local `main` (same file set). Mirror any unpushed commits via GitHub MCP `push_files`.

### Task 17: App icon asset

**Files:** Create `assets/AppIcon.png.b64` (base64 of a 1024×1024 PNG)

GitHub MCP `push_files` is text-only, so the binary PNG cannot be mirrored safely. Commit the icon as base64 text; `make_app.sh` decodes it at build time.

- [ ] **Step 1:** Generate the PNG with Python/PIL in the sandbox: transparent background, Claude-orange (`#D97757`) 12-ray sunburst matching `ClaudeIconView` geometry (rounded-cap rays from 38% to 100% radius, ray width 26% of radius), centered at 70% canvas size. Save to a temp path.
- [ ] **Step 2:** View the generated PNG (Read tool) to confirm it looks right.
- [ ] **Step 3:** `base64 < icon.png > assets/AppIcon.png.b64` (single-line or wrapped both fine — `base64 -d` handles newlines). Decode it back and compare checksums to verify integrity: `base64 -d assets/AppIcon.png.b64 | shasum` must equal `shasum icon.png`.
- [ ] **Step 4: Commit**

```bash
git add assets/AppIcon.png.b64 && git commit -m "chore: app icon asset (base64)"
```

### Task 18: Info.plist + bundle script

**Files:** Create `Resources/Info.plist`, `scripts/make_app.sh`

- [ ] **Step 1: `Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ClaudeUsageWidget</string>
    <key>CFBundleDisplayName</key><string>Claude Usage Widget</string>
    <key>CFBundleIdentifier</key><string>com.sangho.ClaudeUsageWidget</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleExecutable</key><string>ClaudeUsageWidget</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 sangho</string>
</dict>
</plist>
```

- [ ] **Step 2: `scripts/make_app.sh`** (mark executable: `chmod +x`)

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64

APP=build/ClaudeUsageWidget.app
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset

BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ClaudeUsageWidget
cp "$BIN" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

base64 -d assets/AppIcon.png.b64 > build/AppIcon.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/AppIcon.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) build/AppIcon.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force -s - "$APP"
ditto -c -k --keepParent "$APP" build/ClaudeUsageWidget.zip
echo "Built: build/ClaudeUsageWidget.zip"
```

(Ad-hoc `codesign -s -` is required for Apple Silicon to run at all; it does not remove the Gatekeeper warning — README covers that.)

- [ ] **Step 3: Commit**

```bash
git add Resources/Info.plist scripts/make_app.sh
git commit -m "feat(dist): app bundle script and Info.plist (LSUIElement)"
```

### Task 19: GitHub Actions workflow

Already created in Chunk 1 Task 5 (moved earlier so every chunk gets a CI gate).

- [ ] **Step 1:** Verify `.github/workflows/ci.yml` exists and the release job invokes `bash scripts/make_app.sh`. No changes expected.

### Task 20: README

**Files:** Create `README.md` (Korean)

- [ ] **Step 1:** Write README covering: what it is (한 줄 + 메뉴바 스크린샷 자리), 다운로드 (Releases에서 zip → Applications로 이동), 무서명 앱 첫 실행 (`우클릭 → 열기`, 또는 `xattr -cr /Applications/ClaudeUsageWidget.app`), 구독 모드 요구사항 (Claude Code 설치+로그인, 최초 실행 시 키체인 접근 허용 → "항상 허용" 권장), API 모드 설정 (Admin API 키 발급 위치, 월 예산 기본 $200), 색상 의미 (주황=정상, 빨강=80% 초과, 회색=데이터 없음), 직접 빌드 (`bash scripts/make_app.sh`), 라이선스 MIT.
- [ ] **Step 2:** Create `LICENSE` (MIT, copyright 2026 sangho).
- [ ] **Step 3: Commit**

```bash
git add README.md LICENSE && git commit -m "docs: README and MIT license"
```

### Task 21: Final CI verification + release

- [ ] **Step 1:** Mirror all commits to GitHub (Task 16 method). Confirm `test` job green on `main` (poll `https://api.github.com/repos/<owner>/Claude-Usage-Widget/actions/runs?per_page=1` via web_fetch).
- [ ] **Step 2:** Fix-and-repush loop until green (max 5 attempts, then surface to user with logs).
- [ ] **Step 3:** Tag `v0.1.0` and push tag (via GitHub MCP create ref or ask user). Confirm release job green and `ClaudeUsageWidget.zip` attached to the GitHub Release.
- [ ] **Step 4:** Ask the user to download/install and smoke-test: menu bar shows icon+bar+percent; dropdown shows details; Settings switches modes; subscription mode prompts keychain access once.
