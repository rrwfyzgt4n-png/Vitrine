import Foundation
import XCTest
@testable import Vitrine

final class CatalogMaintenanceTests: XCTestCase {
    func testHealthReportIncludesRecordsCoversDuplicatesDamageAndBackups() {
        let sharedPath = "Duplicate.jpg"
        let catalog = CatalogSnapshot(name: "Library", items: [
            CatalogItem(source: SourceFileMetadata(relativePath: sharedPath)),
            CatalogItem(
                source: SourceFileMetadata(relativePath: sharedPath),
                availability: .temporarilyUnavailable
            ),
            CatalogItem(
                source: SourceFileMetadata(relativePath: "Metadata Only.jpg"),
                availability: .metadataOnly
            ),
        ])
        let damagedID = UUID()
        let diagnostics = [
            MarkdownDiagnostic(severity: .error, code: .duplicateRecordID, recordID: UUID(), message: "duplicate"),
            MarkdownDiagnostic(severity: .error, code: .missingRequiredField, recordID: damagedID, message: "damaged"),
            MarkdownDiagnostic(severity: .warning, code: .invalidDate, recordID: damagedID, message: "warning"),
        ]
        let latestDate = Date(timeIntervalSince1970: 20)
        let backups = [
            CatalogBackupService.Backup(url: URL(fileURLWithPath: "/tmp/new.md"), date: latestDate),
            CatalogBackupService.Backup(url: URL(fileURLWithPath: "/tmp/old.md"), date: .distantPast),
        ]

        let report = CatalogHealthService().report(
            catalog: catalog,
            diagnostics: diagnostics,
            backups: backups
        )

        XCTAssertEqual(report.readableRecordCount, 3)
        XCTAssertEqual(report.unavailableCoverCount, 2)
        XCTAssertEqual(report.duplicateRecordCount, 2)
        XCTAssertEqual(report.damagedRecordCount, 1)
        XCTAssertEqual(report.warningCount, 1)
        XCTAssertEqual(report.backupCount, 2)
        XCTAssertEqual(report.latestBackupDate, latestDate)
        XCTAssertFalse(report.isHealthy)
    }

    func testDiagnosticReportExcludesPrivateCatalogContent() {
        let privateID = UUID()
        let catalog = CatalogSnapshot(catalogID: privateID, name: "Private Name", items: [
            CatalogItem(
                source: SourceFileMetadata(
                    relativePath: "Secret Folder/Secret Book.jpg",
                    finderComment: "Private shelf note",
                    portableFingerprint: "private-fingerprint"
                ),
                bibliography: BibliographicMetadata(title: "Secret Book", authors: ["Private Author"]),
                personalNotes: "Private personal note"
            )
        ])
        let health = CatalogHealthService().report(catalog: catalog, diagnostics: [], backups: [])

        let report = CatalogDiagnosticService().report(
            catalog: catalog,
            health: health,
            diagnostics: [],
            scanWarnings: []
        )

        for privateValue in [
            privateID.uuidString, "Private Name", "Secret Folder", "Secret Book",
            "Private Author", "Private shelf note", "Private personal note", "private-fingerprint",
        ] {
            XCTAssertFalse(report.contains(privateValue), "Diagnostic report leaked \(privateValue)")
        }
        XCTAssertTrue(report.contains("Readable records: 1"))
        XCTAssertTrue(report.contains("intentionally excludes"))
    }

    func testRebuildUpdatesExistingSourceInformationWithoutReconcilingRecords() {
        let retainedID = UUID()
        let missingID = UUID()
        let catalog = CatalogSnapshot(name: "Library", items: [
            CatalogItem(
                id: retainedID,
                source: SourceFileMetadata(relativePath: "Retained.jpg", fileSize: 10),
                bibliography: BibliographicMetadata(title: "Confirmed Title", metadataConfirmedByUser: true)
            ),
            CatalogItem(
                id: missingID,
                source: SourceFileMetadata(relativePath: "Missing.jpg", fileSize: 20),
                availability: .temporarilyUnavailable
            ),
        ])
        let scanned = [
            SourceFileMetadata(relativePath: "Retained.jpg", finderComment: "Updated", fileSize: 99),
            SourceFileMetadata(relativePath: "Brand New.jpg", fileSize: 42),
        ]

        let rebuild = CatalogCoverInformationRebuilder().rebuild(
            catalog: catalog,
            scannedSources: scanned
        )

        XCTAssertEqual(rebuild.snapshot.items.map(\.id), [retainedID, missingID])
        XCTAssertEqual(rebuild.snapshot.items[0].source.fileSize, 99)
        XCTAssertEqual(rebuild.snapshot.items[0].source.finderComment, "Updated")
        XCTAssertEqual(rebuild.snapshot.items[0].bibliography.title, "Confirmed Title")
        XCTAssertEqual(rebuild.snapshot.items[1].availability, .temporarilyUnavailable)
        XCTAssertEqual(rebuild.refreshedRecordCount, 1)
        XCTAssertEqual(rebuild.unmatchedRecordCount, 1)
    }
}
