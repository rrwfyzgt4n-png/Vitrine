import XCTest
@testable import Vitrine

final class CatalogBackupAndRecoveryTests: XCTestCase {
    func testBackupRotationKeepsTenNewestCopies() async throws {
        let id = UUID()
        let catalogURL = FileManager.default.temporaryDirectory.appending(path: "\(id.uuidString).md")
        defer { try? FileManager.default.removeItem(at: catalogURL) }
        let service = CatalogBackupService()

        for number in 0..<12 {
            try Data("version \(number)".utf8).write(to: catalogURL)
            try await service.preserveCurrentCatalog(at: catalogURL, catalogID: id)
        }
        let backups = try await service.backups(catalogID: id)
        defer { try? FileManager.default.removeItem(at: backups[0].url.deletingLastPathComponent()) }

        XCTAssertEqual(backups.count, 10)
        let retainedContents = try backups.map { try String(contentsOf: $0.url, encoding: .utf8) }
        XCTAssertTrue(retainedContents.contains("version 11"))
    }

    func testDamagedCatalogIsPreservedAndRecoveryRequiresExplicitRestore() async throws {
        let id = UUID()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(id.uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .zero)
        let original = CatalogSnapshot(catalogID: id, name: "Recoverable")
        var changed = original
        changed.name = "Changed"
        try await coordinator.save(original, to: url)
        try await coordinator.save(changed, to: url)
        try Data("catalog-id: \(id.uuidString)\nthis is damaged".utf8).write(to: url, options: .atomic)

        let recovery = try await CatalogRecoveryService().prepareRecovery(at: url)
        defer { try? FileManager.default.removeItem(at: recovery.preservedDamagedCopyURL) }
        let backups = try await coordinator.backups(catalogID: id)
        defer { if let folder = backups.first?.url.deletingLastPathComponent() { try? FileManager.default.removeItem(at: folder) } }
        let parsedBackup = try XCTUnwrap(recovery.parsedBackup)
        let backup = try XCTUnwrap(recovery.backup)

        XCTAssertEqual(parsedBackup.snapshot.name, "Recoverable")
        let preservedDamage = try String(contentsOf: recovery.preservedDamagedCopyURL, encoding: .utf8)
        XCTAssertTrue(preservedDamage.contains("this is damaged"))
        let damagedOnDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(damagedOnDisk.contains("this is damaged"))

        try await coordinator.restore(backup, to: url, catalogID: id)
        let restoredOnDisk = try await CatalogMarkdownStore().read(from: url)
        XCTAssertEqual(restoredOnDisk.snapshot.name, "Recoverable")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.url.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovery.preservedDamagedCopyURL.path))
    }

    func testRecoveryRemainsAvailableWhenNoValidBackupExists() async throws {
        let id = UUID()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(id.uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("catalog-id: \(id.uuidString)\nthis is damaged".utf8).write(to: url)

        let recovery = try await CatalogRecoveryService().prepareRecovery(at: url)
        defer { try? FileManager.default.removeItem(at: recovery.preservedDamagedCopyURL) }
        let backups = try await CatalogBackupService().backups(catalogID: id)
        defer { if let folder = backups.first?.url.deletingLastPathComponent() { try? FileManager.default.removeItem(at: folder) } }

        XCTAssertEqual(recovery.catalogID, id)
        XCTAssertNil(recovery.backup)
        XCTAssertNil(recovery.parsedBackup)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testMissingCatalogIDUsesRememberedIdentityToFindBackups() async throws {
        let id = UUID()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .zero)
        let original = CatalogSnapshot(catalogID: id, name: "Remembered", items: [
            CatalogItem(source: SourceFileMetadata(relativePath: "Cover.jpg"))
        ])
        var changed = original
        changed.name = "Changed"
        try await coordinator.save(original, to: url)
        try await coordinator.save(changed, to: url)
        try Data("header and identifier are gone".utf8).write(to: url, options: .atomic)

        let recovery = try await CatalogRecoveryService().prepareRecovery(
            at: url,
            rememberedCatalogID: id
        )
        defer { try? FileManager.default.removeItem(at: recovery.preservedDamagedCopyURL) }
        let backups = try await coordinator.backups(catalogID: id)
        defer { if let folder = backups.first?.url.deletingLastPathComponent() { try? FileManager.default.removeItem(at: folder) } }

        XCTAssertEqual(recovery.catalogID, id)
        XCTAssertFalse(recovery.backupOptions.isEmpty)
        XCTAssertEqual(recovery.backupOptions.first?.bookCount, 1)
    }

    func testReadableRecordsCanBeRecoveredWhenHeaderIsDamaged() async throws {
        let id = UUID()
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Readable.jpg"))
        let rendered = try CatalogMarkdownWriter().render(
            CatalogSnapshot(catalogID: id, name: "Damaged", items: [item])
        )
        let marker = MarkdownTokenizer.itemBeginPrefix
        let recordsOnly = String(rendered[try XCTUnwrap(rendered.range(of: marker)).lowerBound...])
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(recordsOnly.utf8).write(to: url, options: .atomic)

        let recovery = try await CatalogRecoveryService().prepareRecovery(
            at: url,
            rememberedCatalogID: id
        )
        defer { try? FileManager.default.removeItem(at: recovery.preservedDamagedCopyURL) }

        XCTAssertEqual(recovery.recoveredCatalog?.snapshot.items.map(\.id), [item.id])
        XCTAssertEqual(recovery.recoveredCatalog?.snapshot.items.first?.source.relativePath, "Readable.jpg")

        let report = CatalogRecoveryService().diagnosticReport(for: recovery)
        XCTAssertFalse(report.contains("Readable.jpg"))
        XCTAssertFalse(report.contains(url.path))
    }

    func testCreatingReplacementCatalogLeavesDamagedDataIntact() async throws {
        let id = UUID()
        let damagedURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-damaged.md")
        let replacementURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)-replacement.md")
        defer {
            try? FileManager.default.removeItem(at: damagedURL)
            try? FileManager.default.removeItem(at: replacementURL)
        }
        let damagedData = Data("catalog-id: \(id.uuidString)\nthis catalog remains damaged".utf8)
        try damagedData.write(to: damagedURL, options: .atomic)
        let recovery = try await CatalogRecoveryService().prepareRecovery(at: damagedURL)
        defer { try? FileManager.default.removeItem(at: recovery.preservedDamagedCopyURL) }

        let replacement = CatalogSnapshot(name: "Replacement")
        try await CatalogSaveCoordinator(editDebounce: .zero).save(replacement, to: replacementURL)
        let parsedReplacement = try await CatalogMarkdownStore().read(from: replacementURL)

        XCTAssertEqual(try Data(contentsOf: damagedURL), damagedData)
        XCTAssertEqual(try Data(contentsOf: recovery.preservedDamagedCopyURL), damagedData)
        XCTAssertEqual(parsedReplacement.snapshot.catalogID, replacement.catalogID)
    }
}
