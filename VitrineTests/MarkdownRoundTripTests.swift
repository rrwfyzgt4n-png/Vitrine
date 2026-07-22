import XCTest
@testable import Vitrine

final class MarkdownRoundTripTests: XCTestCase {
    func testKnownAndUnknownRecordDataSurviveRoundTrip() throws {
        let source = """
        ---
        library-catalog-schema: 1
        catalog-id: 9A50D16E-51E8-4867-B81E-2525F910AD51
        catalog-name: My Library
        created-at: 2026-07-18T20:00:00Z
        updated-at: 2026-07-18T20:20:00Z
        record-count: 1
        custom-front-field: retained
        ---
        # My Library
        A user-managed introduction.

        <!-- library-catalog:item:begin id="86CC391A-4662-4553-902D-E8B80D2641DD" -->
        ## The Trial
        - source-file: `Kafka/The Trial.jpg`
        - source-title: `The Trial`
        - full-content-hash: `full-hash`
        - file-resource-id: `resource-id`
        - availability: `available`
        - date-added: `2026-07-18T19:20:00Z`
        - record-modified: `2026-07-18T19:35:00Z`
        - author: `Franz Kafka`
        - published: `1967`
        - original-published: `1963`
        - metadata-source: `filename`
        - custom-record-field: `retained`
        ### Finder notes
        > Second shelf.
        ### Personal notes
        Read in 2018.
        <!-- library-catalog:item:end -->
        """

        let parser = CatalogMarkdownParser()
        let first = try parser.parse(source).snapshot
        let rendered = try CatalogMarkdownWriter().render(first)
        let second = try parser.parse(rendered).snapshot

        XCTAssertEqual(second.unknownFrontMatter["custom-front-field"], "retained")
        XCTAssertEqual(second.unmanagedText, first.unmanagedText)
        XCTAssertEqual(second.items.first?.unrecognizedLines, ["- custom-record-field: `retained`"])
        XCTAssertEqual(second.items.first?.source.finderComment, "Second shelf.")
        XCTAssertEqual(second.items.first?.personalNotes, "Read in 2018.")
        XCTAssertEqual(second.items.first?.bibliography.authors, ["Franz Kafka"])
        XCTAssertEqual(second.items.first?.bibliography.publicationDate, "1967")
        XCTAssertEqual(second.items.first?.bibliography.originalPublicationDate, "1963")
        XCTAssertEqual(second.items.first?.bibliography.metadataSource, .filename)
        XCTAssertEqual(second.items.first?.source.fullContentHash, "full-hash")
        XCTAssertEqual(second.items.first?.source.fileResourceIdentifier, "resource-id")
    }

    func testStructuredFilenameFieldsSurviveRoundTrip() throws {
        let date = try XCTUnwrap(CatalogDateFormatter.date(from: "2026-07-18T20:00:00Z"))
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Books/Example.jpg"),
            bibliography: .init(
                title: "Example",
                contributors: [.init(name: "Editor Name", roles: [.editor, .annotator])],
                publisher: "Example Press",
                collectionName: "Example Collection",
                collectionNumber: "7",
                publicationPlace: "Montréal",
                volumeDescription: "tome 1",
                languageCode: "fr",
                additionalLanguageCodes: ["it"],
                originalLanguageCode: "en",
                paginationStatus: .nonPaginated,
                physicalAttributes: [.illustrated, .maps]
            ),
            dateAdded: date,
            dateModified: date
        )
        let snapshot = CatalogSnapshot(name: "Test", createdAt: date, updatedAt: date, items: [item])

        let rendered = try CatalogMarkdownWriter().render(snapshot)
        let parsed = try CatalogMarkdownParser().parse(rendered).snapshot

        XCTAssertEqual(parsed.items.first?.bibliography, item.bibliography)
    }
}
