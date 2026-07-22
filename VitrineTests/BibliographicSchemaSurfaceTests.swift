import XCTest
@testable import Vitrine

final class BibliographicSchemaSurfaceTests: XCTestCase {
    func testStoredMetadataFieldsMatchTheExecutableSchemaRegistry() {
        let storedFields = Set(Mirror(reflecting: BibliographicMetadata()).children.compactMap(\.label))
        let registeredFields = Set(BibliographicMetadataField.allCases.map(\.rawValue))

        XCTAssertEqual(storedFields, registeredFields)
    }

    func testEveryBibliographicFieldHasUniqueMarkdownAndMergeMappings() {
        let markdownKeys = BibliographicMetadataField.allCases.flatMap(\.markdownKeys)
        let mergeFields = BibliographicMetadataField.allCases.map { $0.mergeField.rawValue }
        let nonBibliographicMergeFields = Set([
            CatalogMergeField.catalogName, .sourceFolderName, .sourceFolderSignature,
            .record, .source, .personalNotes, .availability, .unrecognizedLines,
        ].map(\.rawValue))
        let expectedMergeFields = Set(CatalogMergeField.allCases.map(\.rawValue))
            .subtracting(nonBibliographicMergeFields)

        XCTAssertEqual(Set(markdownKeys).count, markdownKeys.count)
        XCTAssertEqual(Set(mergeFields).count, mergeFields.count)
        XCTAssertEqual(markdownKeys.count, BibliographicMetadataField.allCases.count)
        XCTAssertEqual(Set(mergeFields), expectedMergeFields)
    }

    func testFullyPopulatedSchemaRoundTripsWithoutLosingAField() throws {
        let date = try XCTUnwrap(CatalogDateFormatter.date(from: "2026-07-22T06:00:00Z"))
        let metadata = BibliographicMetadata(
            isbn10: "0123456789", isbn13: "9780123456786", title: "Title", subtitle: "Subtitle",
            authors: ["Author One", "Author Two"], translators: ["Translator"],
            contributors: [.init(name: "Editor", roles: [.editor, .annotator])], publisher: "Publisher",
            collectionName: "Collection", collectionNumber: "12", publicationPlace: "Montréal",
            publicationDate: "2001", originalPublicationDate: "1999", editionDescription: "Second edition",
            volumeDescription: "Volume 2", languageCode: "fr", additionalLanguageCodes: ["en", "it"],
            originalLanguageCode: "en", pageCount: 321, paginationStatus: .nonPaginated,
            physicalAttributes: [.illustrated, .foldoutMaps], subjects: ["History", "Art"],
            description: "Description", openLibraryEditionID: "OL1M", openLibraryWorkID: "OL1W",
            metadataSource: .mixed, metadataRetrievedAt: date, metadataConfirmedByUser: true
        )
        let snapshot = CatalogSnapshot(name: "Schema", items: [
            CatalogItem(source: SourceFileMetadata(relativePath: "Cover.jpg"), bibliography: metadata)
        ])

        let rendered = try CatalogMarkdownWriter().render(snapshot)
        let reparsed = try CatalogMarkdownParser().parse(rendered).snapshot

        XCTAssertEqual(reparsed.items.first?.bibliography, metadata)
        for key in BibliographicMetadataField.allCases.flatMap(\.markdownKeys) {
            XCTAssertTrue(rendered.contains("- \(key):"), key)
        }
    }
}
