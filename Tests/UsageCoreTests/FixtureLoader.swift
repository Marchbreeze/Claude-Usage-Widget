import Foundation
import XCTest

func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"))
    return try Data(contentsOf: url)
}
