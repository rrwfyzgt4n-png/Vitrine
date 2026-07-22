import Foundation
import XCTest
@testable import Vitrine

final class LocalizationTests: XCTestCase {
    func testEveryCatalogEntryHasFrenchAndCanadianFrenchLocalization() throws {
        let strings = try localizationEntries()

        for (key, rawEntry) in strings {
            let localizations = try localizations(in: rawEntry, key: key)
            XCTAssertNotNil(localizations["fr"], "Missing French localization for \(key)")
            XCTAssertNotNil(localizations["fr-CA"], "Missing Canadian French localization for \(key)")
        }
    }

    func testDynamicConflictFieldLabelsExistInTheLocalizationCatalog() throws {
        let strings = try localizationEntries()

        for field in CatalogMergeField.allCases {
            let rawEntry = try XCTUnwrap(strings[field.rawValue], "Missing localization key for \(field.rawValue)")
            let fieldLocalizations = try localizations(in: rawEntry, key: field.rawValue)
            XCTAssertNotNil(fieldLocalizations["fr"], "Missing French localization for \(field.rawValue)")
            XCTAssertNotNil(fieldLocalizations["fr-CA"], "Missing Canadian French localization for \(field.rawValue)")
        }
    }

    func testAllRegisteredEnumLabelsAreNonempty() {
        XCTAssertTrue(CatalogMergeField.allCases.allSatisfy { !$0.label.isEmpty })
        XCTAssertTrue(ContributorRole.allCases.allSatisfy { !$0.label.isEmpty })
        XCTAssertTrue(PaginationStatus.allCases.allSatisfy { !$0.label.isEmpty })
        XCTAssertTrue(PhysicalAttribute.allCases.allSatisfy { !$0.label.isEmpty })
        XCTAssertTrue(ItemAvailability.allCases.allSatisfy { !$0.inspectorLabel.isEmpty })
        XCTAssertTrue(CatalogSortOption.allCases.allSatisfy { !$0.label.isEmpty })
        XCTAssertTrue(CatalogFilter.allCases.allSatisfy { !$0.label.isEmpty })
    }

    private func localizationEntries() throws -> [String: Any] {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Vitrine/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: sourceURL)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try XCTUnwrap(root["strings"] as? [String: Any])
    }

    private func localizations(in rawEntry: Any, key: String) throws -> [String: Any] {
        let entry = try XCTUnwrap(rawEntry as? [String: Any], "Invalid entry for \(key)")
        return try XCTUnwrap(
            entry["localizations"] as? [String: Any],
            "Missing localizations for \(key)"
        )
    }
}
