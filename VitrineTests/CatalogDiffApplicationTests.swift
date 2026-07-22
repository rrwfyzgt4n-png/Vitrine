import XCTest
@testable import Vitrine

@MainActor
final class CatalogDiffApplicationTests: XCTestCase {
    func testFilesystemDatesAreNormalizedToCatalogPrecision() {
        let date = Date(timeIntervalSince1970: 1_234.987)

        XCTAssertEqual(
            CatalogDateFormatter.normalizedForPersistence(date),
            Date(timeIntervalSince1970: 1_234)
        )
    }

    func testUnchangedRefreshDoesNotRequireCatalogReplacement() {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Cover.jpg"))
        let current = CatalogSnapshot(
            name: "Library",
            sourceFolderName: "Covers",
            sourceFolderSignature: "signature",
            items: [item]
        )
        var proposed = current
        proposed.updatedAt = current.updatedAt.addingTimeInterval(60)

        XCTAssertFalse(CatalogStore.refreshRequiresSave(current: current, proposed: proposed))

        proposed.items[0].source.fileSize = 42
        XCTAssertTrue(CatalogStore.refreshRequiresSave(current: current, proposed: proposed))
    }

    func testSourceDiffAtCurrentBaselineDoesNotRollBackBookDetails() {
        let id = UUID()
        let baselineDate = Date(timeIntervalSince1970: 1_700_000_000)
        let originalSource = SourceFileMetadata(
            relativePath: "Old.jpg",
            portableFingerprint: "fingerprint"
        )
        let refreshedSource = SourceFileMetadata(
            relativePath: "New.jpg",
            portableFingerprint: "fingerprint"
        )
        let expected = SourceRevision(
            relativePath: originalSource.relativePath,
            portableFingerprint: originalSource.portableFingerprint,
            fileModificationDate: originalSource.fileModificationDate
        )
        let diff = CatalogReconciliationDiff(
            baseCatalogID: UUID(),
            baseCatalogUpdatedAt: baselineDate,
            sourceFolderValidated: true,
            scannedSources: [refreshedSource],
            operations: [.updateSource(id: id, expected: expected, newValue: refreshedSource)],
            completedEnumeration: true,
            warnings: []
        )
        let latest = CatalogSnapshot(
            catalogID: diff.baseCatalogID,
            name: "Library",
            updatedAt: baselineDate,
            items: [
                CatalogItem(
                    id: id,
                    source: originalSource,
                    bibliography: BibliographicMetadata(
                        title: "A title added while scanning",
                        metadataConfirmedByUser: true
                    )
                )
            ]
        )

        let result = CatalogStore().apply(diff: diff, to: latest, allowRemovals: true)

        XCTAssertEqual(result.items.first?.source.relativePath, "New.jpg")
        XCTAssertEqual(result.items.first?.bibliography.title, "A title added while scanning")
    }

    func testStaleDiffIsRejectedWithoutApplyingAnyOperations() {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Old.jpg", portableFingerprint: "same"))
        let baseline = Date(timeIntervalSince1970: 1_700_000_000)
        let latest = CatalogSnapshot(
            name: "Library",
            updatedAt: baseline.addingTimeInterval(1),
            items: [item]
        )
        let replacement = SourceFileMetadata(relativePath: "New.jpg", portableFingerprint: "same")
        let diff = CatalogReconciliationDiff(
            baseCatalogID: latest.catalogID,
            baseCatalogUpdatedAt: baseline,
            sourceFolderValidated: true,
            scannedSources: [replacement],
            operations: [.updateSource(
                id: item.id,
                expected: SourceRevision(
                    relativePath: item.source.relativePath,
                    portableFingerprint: item.source.portableFingerprint,
                    fileModificationDate: item.source.fileModificationDate
                ),
                newValue: replacement
            )],
            completedEnumeration: true,
            warnings: []
        )

        let result = CatalogStore().apply(diff: diff, to: latest, allowRemovals: true)

        XCTAssertEqual(result, latest)
    }

    func testUnvalidatedFolderCannotApplyAutomaticRemoval() {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Existing.jpg"))
        let expected = SourceRevision(
            relativePath: item.source.relativePath,
            portableFingerprint: item.source.portableFingerprint,
            fileModificationDate: item.source.fileModificationDate
        )
        let snapshot = CatalogSnapshot(name: "Library", items: [item])
        let diff = CatalogReconciliationDiff(
            baseCatalogID: snapshot.catalogID,
            baseCatalogUpdatedAt: snapshot.updatedAt,
            sourceFolderValidated: false,
            scannedSources: [],
            operations: [.removeRecord(id: item.id, expected: expected)],
            completedEnumeration: true,
            warnings: []
        )

        let result = CatalogStore().apply(diff: diff, to: snapshot, allowRemovals: false)

        XCTAssertEqual(result.items.map(\.id), [item.id])
    }

    func testMetadataOnlyRecordCanStillBeExplicitlyRemoved() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Retained.jpg"),
            availability: .metadataOnly
        )
        let snapshot = CatalogSnapshot(name: "Library", items: [item])
        let coordinator = CatalogSaveCoordinator(editDebounce: .zero)
        try await coordinator.save(snapshot, to: url)
        let store = CatalogStore(saveCoordinator: coordinator, catalogURL: url, undoManagerProvider: { nil })
        store.catalog = snapshot
        store.pendingRemovalItemID = item.id

        let didRemove = await store.confirmBookRemoval()
        let reopened = try await CatalogMarkdownStore().read(from: url).snapshot

        XCTAssertTrue(didRemove)
        XCTAssertTrue(store.catalog?.items.isEmpty == true)
        XCTAssertTrue(reopened.items.isEmpty)
        if let folder = try await coordinator.backups(catalogID: snapshot.catalogID).first?.url.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: folder)
        }
    }
}
