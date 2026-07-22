import XCTest
@testable import Vitrine

final class SaveCoordinatorTests: XCTestCase {
    func testUnsupportedSchemaCatalogCannotBeSaved() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let snapshot = CatalogSnapshot(
            schemaVersion: CatalogSnapshot.supportedSchemaVersion + 1,
            name: "Future Catalog",
            isReadOnly: true
        )

        do {
            try await CatalogSaveCoordinator(editDebounce: .zero).save(snapshot, to: url)
            XCTFail("Expected a read-only future catalog to reject the save")
        } catch let error as CatalogError {
            guard case .unsupportedSchema = error else {
                return XCTFail("Expected unsupportedSchema, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

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

    func testConsecutiveBookDetailSavesKeepBothAcceptedSuggestions() async throws {
        let catalogID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(catalogID.uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .milliseconds(80))
        let base = CatalogSnapshot(
            catalogID: catalogID,
            name: "Library",
            items: [
                CatalogItem(id: firstID, source: SourceFileMetadata(relativePath: "First.jpg")),
                CatalogItem(id: secondID, source: SourceFileMetadata(relativePath: "Second.jpg")),
            ]
        )
        try await coordinator.save(base, to: url)

        var firstAccepted = base
        firstAccepted.items[0].bibliography.title = "First Parsed Title"
        var secondAccepted = firstAccepted
        secondAccepted.items[1].bibliography.title = "Second Parsed Title"
        let firstSave = Task {
            try await coordinator.save(firstAccepted, to: url, reason: .metadataEdit)
        }
        try await Task.sleep(for: .milliseconds(10))
        let secondSave = Task {
            try await coordinator.save(secondAccepted, to: url, reason: .metadataEdit)
        }
        try await firstSave.value
        try await secondSave.value

        let parsed = try await CatalogMarkdownStore().read(from: url).snapshot
        let items = Dictionary(uniqueKeysWithValues: parsed.items.map { ($0.id, $0) })
        XCTAssertEqual(items[firstID]?.bibliography.title, "First Parsed Title")
        XCTAssertEqual(items[secondID]?.bibliography.title, "Second Parsed Title")
        let backups = try await coordinator.backups(catalogID: catalogID)
        if let folder = backups.first?.url.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    func testExternalDiskChangeIsNotOverwritten() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .zero)
        var baseline = CatalogSnapshot(name: "Baseline")
        try await coordinator.save(baseline, to: url)

        var external = baseline
        external.name = "External"
        external.updatedAt = Date(timeIntervalSince1970: 2)
        let externalData = try XCTUnwrap(try CatalogMarkdownWriter().render(external).data(using: .utf8))
        try externalData.write(to: url, options: .atomic)

        baseline.name = "Local"
        baseline.updatedAt = Date(timeIntervalSince1970: 3)
        do {
            try await coordinator.save(baseline, to: url)
            XCTFail("Expected the changed disk baseline to block the save")
        } catch let error as CatalogError {
            guard case .externalConflict = error else {
                return XCTFail("Expected externalConflict, got \(error)")
            }
        }

        let parsed = try await CatalogMarkdownStore().read(from: url)
        XCTAssertEqual(parsed.snapshot.name, "External")
    }

    func testRestoreRefreshesBaselineForTheNextSave() async throws {
        let id = UUID()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(id.uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .zero)
        let original = CatalogSnapshot(catalogID: id, name: "Original")
        var changed = original
        changed.name = "Changed"
        try await coordinator.save(original, to: url)
        try await coordinator.save(changed, to: url)
        let backups = try await coordinator.backups(catalogID: id)
        let backup = try XCTUnwrap(backups.first)
        defer { try? FileManager.default.removeItem(at: backup.url.deletingLastPathComponent()) }

        let restored = try await coordinator.restore(backup, to: url, catalogID: id)
        var editedAfterRestore = restored
        editedAfterRestore.name = "Edited After Restore"
        try await coordinator.save(editedAfterRestore, to: url)

        let parsed = try await CatalogMarkdownStore().read(from: url)
        XCTAssertEqual(parsed.snapshot.name, "Edited After Restore")
    }
}
