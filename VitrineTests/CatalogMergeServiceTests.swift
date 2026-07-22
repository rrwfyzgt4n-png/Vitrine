import XCTest
@testable import Vitrine

final class CatalogMergeServiceTests: XCTestCase {
    func testIndependentFieldChangesMergeWithoutConflict() async {
        let id = UUID()
        let baseItem = CatalogItem(
            id: id,
            source: SourceFileMetadata(relativePath: "Cover.jpg"),
            bibliography: BibliographicMetadata(title: "Base", publisher: "Base Publisher")
        )
        let base = CatalogSnapshot(name: "Library", items: [baseItem])
        var local = base
        local.items[0].bibliography.title = "Local Title"
        var external = base
        external.items[0].bibliography.publisher = "External Publisher"

        let pending = await CatalogMergeService().merge(base: base, local: local, external: external)

        XCTAssertTrue(pending.conflicts.isEmpty)
        XCTAssertEqual(pending.merged.items[0].bibliography.title, "Local Title")
        XCTAssertEqual(pending.merged.items[0].bibliography.publisher, "External Publisher")
    }

    func testSameFieldConflictCanResolveToExternalValue() async {
        let id = UUID()
        let baseItem = CatalogItem(
            id: id,
            source: SourceFileMetadata(relativePath: "Cover.jpg"),
            bibliography: BibliographicMetadata(title: "Base")
        )
        let base = CatalogSnapshot(name: "Library", items: [baseItem])
        var local = base
        local.items[0].bibliography.title = "Local"
        var external = base
        external.items[0].bibliography.title = "External"
        let service = CatalogMergeService()

        let pending = await service.merge(base: base, local: local, external: external)
        let conflict = try! XCTUnwrap(pending.conflicts.first { $0.field == .title })
        let resolved = await service.resolving(pending, useExternal: [conflict.id])

        XCTAssertEqual(resolved.items[0].bibliography.title, "External")
    }

    func testUsingOtherConflictValuePreservesUnrelatedLocalEdit() async throws {
        let id = UUID()
        let baseItem = CatalogItem(
            id: id,
            source: SourceFileMetadata(relativePath: "Cover.jpg"),
            bibliography: BibliographicMetadata(title: "Base", publisher: "Base Publisher")
        )
        let base = CatalogSnapshot(name: "Library", items: [baseItem])
        var local = base
        local.items[0].bibliography.title = "Local Title"
        local.items[0].bibliography.publisher = "Local Publisher"
        var external = base
        external.items[0].bibliography.title = "External Title"
        let service = CatalogMergeService()

        let pending = await service.merge(base: base, local: local, external: external)
        let titleConflict = try XCTUnwrap(pending.conflicts.first { $0.field == .title })
        let keepMine = await service.resolving(pending, useExternal: [])
        let resolved = await service.resolving(pending, useExternal: [titleConflict.id])

        XCTAssertEqual(keepMine.items[0].bibliography.title, "Local Title")
        XCTAssertEqual(keepMine.items[0].bibliography.publisher, "Local Publisher")
        XCTAssertEqual(resolved.items[0].bibliography.title, "External Title")
        XCTAssertEqual(resolved.items[0].bibliography.publisher, "Local Publisher")
    }

    func testDeletedVersusEditedRecordRequiresExplicitChoice() async throws {
        let id = UUID()
        let baseItem = CatalogItem(
            id: id,
            source: SourceFileMetadata(relativePath: "Cover.jpg"),
            bibliography: BibliographicMetadata(title: "Base")
        )
        let base = CatalogSnapshot(name: "Library", items: [baseItem])
        var local = base
        local.items[0].bibliography.title = "Locally Edited"
        var external = base
        external.items = []
        let service = CatalogMergeService()

        let pending = await service.merge(base: base, local: local, external: external)
        let recordConflict = try XCTUnwrap(pending.conflicts.first { $0.field == .record })
        let keepLocal = await service.resolving(pending, useExternal: [])
        let useDeletion = await service.resolving(pending, useExternal: [recordConflict.id])

        XCTAssertEqual(keepLocal.items.first?.bibliography.title, "Locally Edited")
        XCTAssertTrue(useDeletion.items.isEmpty)
    }
}
