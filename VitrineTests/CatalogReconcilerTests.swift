import XCTest
@testable import Vitrine

final class CatalogReconcilerTests: XCTestCase {
    func testCompleteScanRemovesConfirmedMissingRecord() async {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Missing.jpg", portableFingerprint: "old"))
        let catalog = CatalogSnapshot(name: "Test", items: [item])
        let scan = CatalogScanResult(sources: [], completedEnumeration: true, warnings: [])

        let diff = await CatalogReconciler().diff(catalog: catalog, scan: scan)

        XCTAssertEqual(diff.operations, [
            .removeRecord(
                id: item.id,
                expected: SourceRevision(relativePath: "Missing.jpg", portableFingerprint: "old", fileModificationDate: nil)
            )
        ])
    }

    func testIncompleteScanNeverRemovesRecord() async {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Missing.jpg", portableFingerprint: "old"))
        let catalog = CatalogSnapshot(name: "Test", items: [item])
        let scan = CatalogScanResult(
            sources: [],
            completedEnumeration: false,
            warnings: [CatalogScanWarning(relativePath: "Changing.jpg", message: "Retry later")]
        )

        let diff = await CatalogReconciler().diff(catalog: catalog, scan: scan)

        XCTAssertEqual(diff.operations.first, .markMissing(
            id: item.id,
            expected: SourceRevision(relativePath: "Missing.jpg", portableFingerprint: "old", fileModificationDate: nil)
        ))
        XCTAssertFalse(diff.operations.contains { if case .removeRecord = $0 { true } else { false } })
    }

    func testFingerprintRenameRetainsRecordIdentityAndMetadata() async {
        let id = UUID()
        let item = CatalogItem(
            id: id,
            source: SourceFileMetadata(relativePath: "Old.jpg", portableFingerprint: "same"),
            bibliography: BibliographicMetadata(title: "Confirmed", metadataConfirmedByUser: true)
        )
        let moved = SourceFileMetadata(relativePath: "Nested/New.jpg", portableFingerprint: "same")

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Test", items: [item]),
            scan: CatalogScanResult(sources: [moved], completedEnumeration: true, warnings: [])
        )

        XCTAssertEqual(diff.operations, [
            .updateSource(
                id: id,
                expected: SourceRevision(relativePath: "Old.jpg", portableFingerprint: "same", fileModificationDate: nil),
                newValue: moved
            )
        ])
    }
}
