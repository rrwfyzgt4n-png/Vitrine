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

    func testSourceDiffAppliesToLatestCatalogWithoutRollingBackBookDetails() {
        let id = UUID()
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
            baseCatalogUpdatedAt: .distantPast,
            sourceFolderValidated: true,
            scannedSources: [refreshedSource],
            operations: [.updateSource(id: id, expected: expected, newValue: refreshedSource)],
            completedEnumeration: true,
            warnings: []
        )
        let latest = CatalogSnapshot(
            catalogID: diff.baseCatalogID,
            name: "Library",
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
}
