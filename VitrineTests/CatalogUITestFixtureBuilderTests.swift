import XCTest
@testable import Vitrine

final class CatalogUITestFixtureBuilderTests: XCTestCase {
    private let builder = CatalogUITestFixtureBuilder()

    func testFixtureRequiresExplicitUITestEnvironment() {
        XCTAssertNil(builder.build(
            arguments: ["Vitrine", "-VitrineUITestFixture", "available"],
            environment: [:]
        ))
    }

    func testScaleFixtureBuildsFiveThousandStableRecords() throws {
        let fixture = try XCTUnwrap(build("scale5000"))

        XCTAssertEqual(fixture.snapshot.items.count, 5_000)
        XCTAssertEqual(fixture.snapshot.items.first?.displayTitle, "Book 0001")
        XCTAssertEqual(fixture.snapshot.items.last?.displayTitle, "Book 5000")
        XCTAssertTrue(fixture.snapshot.items.allSatisfy { $0.availability == .metadataOnly })
    }

    func testUnsupportedFixtureIsReadOnly() throws {
        let fixture = try XCTUnwrap(build("unsupported"))

        XCTAssertTrue(fixture.snapshot.isReadOnly)
        XCTAssertGreaterThan(fixture.snapshot.schemaVersion, CatalogSnapshot.supportedSchemaVersion)
    }

    func testConflictAndRecoveryFixturesCarryOnlyTheirRequestedPresentation() throws {
        let conflict = try XCTUnwrap(build("conflict"))
        let repair = try XCTUnwrap(build("repair"))

        XCTAssertEqual(conflict.pendingMerge?.conflicts.count, 1)
        XCTAssertNil(conflict.pendingRecovery)
        XCTAssertNil(repair.pendingMerge)
        XCTAssertEqual(repair.pendingRecovery?.backupOptions.count, 1)
    }

    private func build(_ name: String) -> CatalogUITestFixture? {
        builder.build(
            arguments: ["Vitrine", "-VitrineUITestFixture", name],
            environment: ["VITRINE_UI_TESTING": "1"]
        )
    }
}
