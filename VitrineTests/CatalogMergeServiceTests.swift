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
}
