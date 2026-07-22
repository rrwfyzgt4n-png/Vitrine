import XCTest
@testable import Vitrine

final class MarkdownWriterTests: XCTestCase {
    func testWriterIsDeterministicAndSortsRecords() throws {
        let date = try XCTUnwrap(CatalogDateFormatter.date(from: "2026-07-18T20:00:00Z"))
        let second = CatalogItem(
            id: UUID(uuidString: "86CC391A-4662-4553-902D-E8B80D2641DD")!,
            source: SourceFileMetadata(relativePath: "Kafka/The Trial.jpg"),
            bibliography: .init(title: "The Trial", authors: ["Franz Kafka"], metadataSource: .manual, metadataConfirmedByUser: true),
            dateAdded: date,
            dateModified: date
        )
        let first = CatalogItem(
            id: UUID(uuidString: "6E0B21A4-4763-47D9-A3B1-4A8853CB818B")!,
            source: SourceFileMetadata(relativePath: "Austen/Emma.jpg"),
            dateAdded: date,
            dateModified: date
        )
        let snapshot = CatalogSnapshot(
            catalogID: UUID(uuidString: "9A50D16E-51E8-4867-B81E-2525F910AD51")!,
            name: "My Library",
            createdAt: date,
            updatedAt: date,
            items: [second, first]
        )

        let writer = CatalogMarkdownWriter()
        let rendered = try writer.render(snapshot)

        XCTAssertEqual(rendered, try writer.render(snapshot))
        XCTAssertLessThan(try XCTUnwrap(rendered.range(of: "## Emma")?.lowerBound), try XCTUnwrap(rendered.range(of: "## The Trial")?.lowerBound))
        XCTAssertTrue(rendered.hasSuffix("\n"))
        XCTAssertFalse(rendered.contains("\r"))
    }

    func testReadOnlyCatalogCannotBeRendered() {
        let snapshot = CatalogSnapshot(schemaVersion: 2, name: "Future", isReadOnly: true)

        XCTAssertThrowsError(try CatalogMarkdownWriter().render(snapshot))
    }

    func testFinderAndPersonalNotesNormalizeEveryLineEndingWithoutChangingStyles() throws {
        let lineEndingVariants = ["First\r\n\r\nSecond", "First\r\rSecond", "First\n\nSecond"]
        for notes in lineEndingVariants {
            let item = CatalogItem(
                source: SourceFileMetadata(relativePath: "Cover.jpg", finderComment: notes),
                personalNotes: notes
            )
            let rendered = try CatalogMarkdownWriter().render(CatalogSnapshot(name: "Notes", items: [item]))

            XCTAssertTrue(rendered.contains("### Finder notes\n> First\n> \n> Second"))
            XCTAssertTrue(rendered.contains("### Personal notes\nFirst\n\nSecond"))
            XCTAssertFalse(rendered.contains("\r"))
            XCTAssertTrue(rendered.hasSuffix("\n"))
            let reparsed = try CatalogMarkdownParser().parse(rendered).snapshot.items[0]
            XCTAssertEqual(reparsed.source.finderComment, "First\n\nSecond")
            XCTAssertEqual(reparsed.personalNotes, "First\n\nSecond")
        }
    }

    func testEmptyNotesProduceNoHeadings() throws {
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Cover.jpg", finderComment: ""),
            personalNotes: ""
        )
        let rendered = try CatalogMarkdownWriter().render(CatalogSnapshot(name: "Notes", items: [item]))

        XCTAssertFalse(rendered.contains("### Finder notes"))
        XCTAssertFalse(rendered.contains("### Personal notes"))
    }

    func testSourceLessConfirmedTitleRetainsMetadataConfirmationCompatibility() throws {
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Cover.jpg"),
            bibliography: BibliographicMetadata(title: "Legacy Title", metadataConfirmedByUser: true)
        )
        let rendered = try CatalogMarkdownWriter().render(CatalogSnapshot(name: "Legacy", items: [item]))
        let reparsed = try CatalogMarkdownParser().parse(rendered).snapshot

        XCTAssertTrue(rendered.contains("- metadata-confirmed: `true`"))
        XCTAssertEqual(reparsed.items.first?.bibliography.metadataSource, nil)
        XCTAssertEqual(reparsed.items.first?.bibliography.metadataConfirmedByUser, true)
    }

    func testProvenanceWithoutTitlePersistsFalseConfirmation() throws {
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Cover.jpg"),
            bibliography: BibliographicMetadata(metadataSource: .manual, metadataConfirmedByUser: false)
        )
        let rendered = try CatalogMarkdownWriter().render(CatalogSnapshot(name: "Provenance", items: [item]))
        let reparsed = try CatalogMarkdownParser().parse(rendered).snapshot

        XCTAssertTrue(rendered.contains("- metadata-confirmed: `false`"))
        XCTAssertEqual(reparsed.items.first?.bibliography.metadataSource, .manual)
        XCTAssertEqual(reparsed.items.first?.bibliography.metadataConfirmedByUser, false)
    }
}
