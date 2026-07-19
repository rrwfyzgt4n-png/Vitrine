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
        let backups = try await coordinator.backups(catalogID: id)
        defer { if let folder = backups.first?.url.deletingLastPathComponent() { try? FileManager.default.removeItem(at: folder) } }

        XCTAssertEqual(recovery.parsedBackup.snapshot.name, "Recoverable")
        XCTAssertTrue(backups.contains { (try? String(contentsOf: $0.url, encoding: .utf8))?.contains("this is damaged") == true })
        let damagedOnDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(damagedOnDisk.contains("this is damaged"))

        try await coordinator.restore(recovery.backup, to: url, catalogID: id)
        let restoredOnDisk = try await CatalogMarkdownStore().read(from: url)
        XCTAssertEqual(restoredOnDisk.snapshot.name, "Recoverable")
    }
}
