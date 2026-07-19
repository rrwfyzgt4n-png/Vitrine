import XCTest
@testable import Vitrine

final class SaveCoordinatorTests: XCTestCase {
    func testSaveCoordinatorCreatesParseableCatalog() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let date = try XCTUnwrap(CatalogDateFormatter.date(from: "2026-07-18T20:00:00Z"))
        let snapshot = CatalogSnapshot(
            catalogID: UUID(uuidString: "9A50D16E-51E8-4867-B81E-2525F910AD51")!,
            name: "My Library",
            createdAt: date,
            updatedAt: date,
            items: [
                CatalogItem(
                    id: UUID(uuidString: "86CC391A-4662-4553-902D-E8B80D2641DD")!,
                    source: SourceFileMetadata(relativePath: "Kafka/The Trial.jpg"),
                    dateAdded: date,
                    dateModified: date
                )
            ]
        )

        try await CatalogSaveCoordinator().save(snapshot, to: url)
        let parsed = try await CatalogMarkdownStore().read(from: url)

        XCTAssertEqual(parsed.snapshot.catalogID, snapshot.catalogID)
        XCTAssertEqual(parsed.snapshot.items.map(\.source.relativePath), ["Kafka/The Trial.jpg"])
    }

    func testOverlappingMetadataSavesCollapseToNewestSnapshot() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .milliseconds(80))
        var first = CatalogSnapshot(name: "First")
        first.updatedAt = Date(timeIntervalSince1970: 1)
        var newest = first
        newest.name = "Newest"
        newest.updatedAt = Date(timeIntervalSince1970: 2)

        let firstSave = Task { try await coordinator.save(first, to: url, reason: .metadataEdit) }
        try await Task.sleep(for: .milliseconds(10))
        let newestSave = Task { try await coordinator.save(newest, to: url, reason: .metadataEdit) }
        try await firstSave.value
        try await newestSave.value

        let parsed = try await CatalogMarkdownStore().read(from: url)
        XCTAssertEqual(parsed.snapshot.name, "Newest")
    }
}
