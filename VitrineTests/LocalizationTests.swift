import Foundation
import XCTest

final class LocalizationTests: XCTestCase {
    func testEveryCatalogEntryHasFrenchAndCanadianFrenchLocalization() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Vitrine/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: sourceURL)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])

        for (key, rawEntry) in strings {
            let entry = try XCTUnwrap(rawEntry as? [String: Any], "Invalid entry for \(key)")
            let localizations = try XCTUnwrap(
                entry["localizations"] as? [String: Any],
                "Missing localizations for \(key)"
            )
            XCTAssertNotNil(localizations["fr"], "Missing French localization for \(key)")
            XCTAssertNotNil(localizations["fr-CA"], "Missing Canadian French localization for \(key)")
        }
    }
}
