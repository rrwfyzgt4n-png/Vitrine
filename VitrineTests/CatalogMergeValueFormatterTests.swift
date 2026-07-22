import XCTest
@testable import Vitrine

final class CatalogMergeValueFormatterTests: XCTestCase {
    private let formatter = CatalogMergeValueFormatter()

    func testSpecializedBibliographicValuesUseLocalizedDisplayConventions() {
        let contributors = [
            BibliographicContributor(name: "Anne Editor", roles: [.editor, .illustrator]),
            BibliographicContributor(name: "Marc Cartographer", roles: [.cartographer]),
        ]

        XCTAssertEqual(
            formatter.string(for: contributors),
            "Anne Editor (\(L10n.text("Editor")), \(L10n.text("Illustrator"))); Marc Cartographer (\(L10n.text("Cartographer")))"
        )
        XCTAssertEqual(
            formatter.string(for: [PhysicalAttribute.illustrated, .foldoutMaps]),
            "\(L10n.text("Illustrated")), \(L10n.text("Fold-out maps"))"
        )
        XCTAssertEqual(formatter.string(for: PaginationStatus.nonPaginated), L10n.text("Non-paginated"))
    }

    func testNilEmptyAndPopulatedValuesRemainDistinct() {
        XCTAssertEqual(formatter.string(for: nil as String?), L10n.text("Not set"))
        XCTAssertEqual(formatter.string(for: ""), L10n.text("Empty"))
        XCTAssertEqual(formatter.string(for: [String]()), L10n.text("Empty"))
        XCTAssertEqual(formatter.string(for: [BibliographicContributor]()), L10n.text("Empty"))
        XCTAssertEqual(formatter.string(for: [PhysicalAttribute]()), L10n.text("Empty"))
        XCTAssertEqual(formatter.string(for: true), L10n.text("Yes"))
        XCTAssertEqual(formatter.string(for: false), L10n.text("No"))
    }

    func testEveryMergeFieldHasAReadableSampleWithoutSwiftDebugSyntax() {
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Nested/Cover.jpg"),
            bibliography: BibliographicMetadata(title: "Readable Book")
        )
        let samples: [CatalogMergeField: Any] = [
            .catalogName: "Library", .sourceFolderName: "Covers", .sourceFolderSignature: "Identity",
            .record: item, .source: item.source, .isbn10: "0123456789", .isbn13: "9780123456786",
            .title: "Title", .subtitle: "Subtitle", .authors: ["Author"], .translators: ["Translator"],
            .contributors: [BibliographicContributor(name: "Contributor", roles: [.editor])],
            .publisher: "Publisher", .collectionName: "Collection", .collectionNumber: "7",
            .publicationPlace: "Montréal", .publicationDate: "2001", .originalPublicationDate: "1999",
            .editionDescription: "Second edition", .volumeDescription: "Volume 2", .languageCode: "fr",
            .additionalLanguageCodes: ["en", "it"], .originalLanguageCode: "en", .pageCount: 320,
            .paginationStatus: PaginationStatus.nonPaginated,
            .physicalAttributes: [PhysicalAttribute.illustrated, .maps], .subjects: ["History", "Art"],
            .description: "Description", .openLibraryEditionID: "OL1M", .openLibraryWorkID: "OL1W",
            .metadataSource: MetadataSource.mixed, .metadataRetrievedAt: Date(timeIntervalSince1970: 0),
            .metadataConfirmedByUser: true, .personalNotes: "Notes", .availability: ItemAvailability.metadataOnly,
            .unrecognizedLines: ["custom data"],
        ]

        XCTAssertEqual(Set(samples.keys.map(\.rawValue)), Set(CatalogMergeField.allCases.map(\.rawValue)))
        for field in CatalogMergeField.allCases {
            let value = formatter.string(for: samples[field] as Any)
            XCTAssertFalse(value.isEmpty, field.rawValue)
            XCTAssertFalse(value.contains("Optional("), field.rawValue)
            XCTAssertFalse(value.contains("BibliographicContributor("), field.rawValue)
            XCTAssertFalse(value.contains("PhysicalAttribute."), field.rawValue)
        }
    }
}
