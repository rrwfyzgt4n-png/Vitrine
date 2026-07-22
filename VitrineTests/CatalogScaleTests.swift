import Foundation
import XCTest
@testable import Vitrine

final class CatalogScaleTests: XCTestCase {
    func testFifteenHundredBookCatalogRoundTripsAtPracticalFileSize() throws {
        let fixedDate = Date(timeIntervalSince1970: 1_750_000_000)
        let items = (0..<1_500).map { number in
            CatalogItem(
                source: SourceFileMetadata(
                    relativePath: "Collection/Book Cover \(number).jpg",
                    finderComment: "Original cover scan; shelf \(number % 24)",
                    portableFingerprint: "fingerprint-\(number)",
                    fileSize: Int64(250_000 + number),
                    pixelWidth: 1_600,
                    pixelHeight: 2_400,
                    fileCreationDate: fixedDate,
                    fileModificationDate: fixedDate
                ),
                bibliography: BibliographicMetadata(
                    isbn13: String(format: "978000%07d", number),
                    title: "A Representative Library Book Number \(number)",
                    subtitle: "History, art, and collected studies",
                    authors: ["Author \(number)", "Contributor \(number % 30)"],
                    publisher: "Representative Press",
                    collectionName: "Vitrine Scale Collection",
                    publicationPlace: "Montréal",
                    publicationDate: "\(1900 + number % 126)",
                    originalPublicationDate: "\(1850 + number % 150)",
                    editionDescription: "Illustrated edition",
                    volumeDescription: "Volume \(1 + number % 12)",
                    languageCode: number.isMultiple(of: 2) ? "fr" : "en",
                    pageCount: 120 + number % 900,
                    physicalAttributes: [.illustrated],
                    subjects: ["History", "Books", "Subject \(number % 50)"],
                    description: "A realistic catalog description retained as user-confirmed bibliographic information.",
                    metadataSource: .manual,
                    metadataConfirmedByUser: true
                ),
                personalNotes: "Personal shelving note for volume \(number).",
                dateAdded: fixedDate,
                dateModified: fixedDate
            )
        }
        let snapshot = CatalogSnapshot(
            name: "1,500 Book Scale Test",
            createdAt: fixedDate,
            updatedAt: fixedDate,
            sourceFolderName: "Covers",
            sourceFolderSignature: "scale-test-volume:Covers",
            items: items
        )

        let startedAt = Date()
        let markdown = try CatalogMarkdownWriter().render(snapshot)
        let renderedAt = Date()
        let parsed = try CatalogMarkdownParser().parse(markdown)
        let completedAt = Date()
        let byteCount = markdown.lengthOfBytes(using: .utf8)

        print(
            "VITRINE_SCALE_METRIC books=1500 bytes=\(byteCount) " +
            "render_ms=\(Int(renderedAt.timeIntervalSince(startedAt) * 1_000)) " +
            "parse_ms=\(Int(completedAt.timeIntervalSince(renderedAt) * 1_000))"
        )
        XCTAssertEqual(parsed.snapshot.items.count, 1_500)
        XCTAssertEqual(parsed.snapshot.items.first?.bibliography.metadataConfirmedByUser, true)
        XCTAssertLessThan(byteCount, 5_000_000, "A realistic 1,500-book catalog should remain only a few MB.")
    }
}
