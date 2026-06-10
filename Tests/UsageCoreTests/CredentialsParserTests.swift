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
