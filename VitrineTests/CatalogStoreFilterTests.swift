import Foundation
import XCTest
@testable import Vitrine

@MainActor
final class CatalogStoreFilterTests: XCTestCase {
    func testRememberedLibraryIsNeverRestoredByUnitTestHost() {
        XCTAssertFalse(CatalogStore.shouldRestoreLastCatalog(
            arguments: ["Vitrine"],
            environment: ["VITRINE_UNIT_TESTING": "1"]
        ))
        XCTAssertFalse(CatalogStore.shouldRestoreLastCatalog(
            arguments: ["Vitrine", "-VitrineSkipRestoreLastCatalog"],
            environment: [:]
        ))
        XCTAssertTrue(CatalogStore.shouldRestoreLastCatalog(
            arguments: ["Vitrine"],
            environment: [:]
        ))
    }

    func testNeedsReviewShowsEveryBookWithoutReviewedFilenameMetadata() {
        let defaults = UserDefaults.standard
        let originalFilter = defaults.object(forKey: "catalogFilter")
        defer {
            if let originalFilter {
                defaults.set(originalFilter, forKey: "catalogFilter")
            } else {
                defaults.removeObject(forKey: "catalogFilter")
            }
        }

        defaults.removeObject(forKey: "catalogFilter")
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(
            name: "Library",
            items: [
                CatalogItem(source: SourceFileMetadata(relativePath: "Unparsed.jpg")),
                CatalogItem(
                    source: SourceFileMetadata(relativePath: "Manual.jpg"),
                    bibliography: BibliographicMetadata(metadataSource: .manual)
                ),
                CatalogItem(
                    source: SourceFileMetadata(relativePath: "OpenLibrary.jpg"),
                    bibliography: BibliographicMetadata(metadataSource: .openLibrary)
                ),
                CatalogItem(
                    source: SourceFileMetadata(relativePath: "Parsed.jpg"),
                    bibliography: BibliographicMetadata(metadataSource: .filename)
                ),
                CatalogItem(
                    source: SourceFileMetadata(relativePath: "ParsedThenEdited.jpg"),
                    bibliography: BibliographicMetadata(metadataSource: .mixed)
                ),
            ]
        )

        store.filter = .needsReview
        XCTAssertEqual(
            Set(store.visibleItems.map(\.source.filename)),
            ["Unparsed.jpg", "Manual.jpg", "OpenLibrary.jpg"]
        )
        XCTAssertEqual(store.filenameReviewCount, 3)

        store.filter = .all
        XCTAssertEqual(store.visibleItems.count, 5)
    }

    func testShowBooksNeedingReviewClearsSearchAndSelectsNextFilename() {
        let parsed = CatalogItem(
            source: SourceFileMetadata(relativePath: "Parsed.jpg"),
            bibliography: BibliographicMetadata(metadataSource: .filename)
        )
        let unparsed = CatalogItem(source: SourceFileMetadata(relativePath: "Unparsed.jpg"))
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [parsed, unparsed])
        store.selection = parsed.id
        store.searchText = "nothing"

        store.showBooksNeedingFilenameReview()

        XCTAssertEqual(store.filter, .needsReview)
        XCTAssertTrue(store.searchText.isEmpty)
        XCTAssertNil(store.selection)

        store.reviewNextFilename()

        XCTAssertEqual(store.selection, unparsed.id)
        XCTAssertTrue(store.isFilenameReviewPresented)
    }

    func testRemovalConfirmationTargetsTheRequestedBook() {
        let first = CatalogItem(source: SourceFileMetadata(relativePath: "First.jpg"))
        let second = CatalogItem(source: SourceFileMetadata(relativePath: "Second.jpg"))
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [first, second])
        store.selection = first.id

        store.requestBookRemoval(itemID: second.id)

        XCTAssertTrue(store.isRemovalConfirmationPresented)
        XCTAssertEqual(store.pendingRemovalItem?.id, second.id)

        store.cancelBookRemoval()
        XCTAssertFalse(store.isRemovalConfirmationPresented)
        XCTAssertNil(store.pendingRemovalItem)
    }

    func testReadOnlyCatalogCannotRequestBookRemoval() {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Book.jpg"))
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [item], isReadOnly: true)

        store.requestBookRemoval(itemID: item.id)

        XCTAssertFalse(store.isRemovalConfirmationPresented)
        XCTAssertNil(store.pendingRemovalItem)
    }

    func testDerivedSearchAndSortIndexInvalidatesWhenCatalogChanges() {
        let first = CatalogItem(
            source: SourceFileMetadata(relativePath: "Zulu.jpg"),
            bibliography: BibliographicMetadata(
                title: "Zulu",
                authors: ["Old Search Token"],
                metadataConfirmedByUser: true
            )
        )
        let second = CatalogItem(
            source: SourceFileMetadata(relativePath: "Bravo.jpg"),
            bibliography: BibliographicMetadata(title: "Bravo", metadataConfirmedByUser: true)
        )
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [first, second])
        store.sortOption = .titleAscending

        XCTAssertEqual(store.visibleItems.map(\.id), [second.id, first.id])
        store.searchText = "old search token"
        XCTAssertEqual(store.visibleItems.map(\.id), [first.id])

        var changed = store.catalog!
        changed.items[0].bibliography.title = "Alpha"
        changed.items[0].bibliography.authors = ["New Search Token"]
        store.catalog = changed
        store.searchText = ""
        XCTAssertEqual(store.visibleItems.map(\.id), [first.id, second.id])
        store.searchText = "old search token"
        XCTAssertTrue(store.visibleItems.isEmpty)
        store.searchText = "new search token"
        XCTAssertEqual(store.visibleItems.map(\.id), [first.id])
    }

    func testBibliographicFiltersSeparatePresentAndMissingValues() {
        let complete = CatalogItem(
            source: SourceFileMetadata(relativePath: "Complete.jpg"),
            bibliography: BibliographicMetadata(
                publicationDate: "2000",
                languageCode: "fr",
                pageCount: 160,
                physicalAttributes: [.illustrated]
            )
        )
        let missing = CatalogItem(source: SourceFileMetadata(relativePath: "Missing.jpg"))
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [complete, missing])

        let expected: [(CatalogFilter, CatalogItem.ID)] = [
            (.hasPublicationYear, complete.id),
            (.missingPublicationYear, missing.id),
            (.hasLanguage, complete.id),
            (.missingLanguage, missing.id),
            (.hasPageCount, complete.id),
            (.missingPageCount, missing.id),
            (.hasPhysicalAttributes, complete.id),
            (.missingPhysicalAttributes, missing.id),
        ]

        for (filter, expectedID) in expected {
            store.filter = filter
            XCTAssertEqual(store.visibleItems.map(\.id), [expectedID], "Unexpected result for \(filter)")
        }
    }

    func testBibliographicSortsPlaceMissingValuesLast() {
        let older = CatalogItem(
            source: SourceFileMetadata(relativePath: "Older.jpg"),
            bibliography: BibliographicMetadata(
                publicationDate: "Édition 1950",
                languageCode: "fr",
                pageCount: 400,
                physicalAttributes: [.maps]
            )
        )
        let newer = CatalogItem(
            source: SourceFileMetadata(relativePath: "Newer.jpg"),
            bibliography: BibliographicMetadata(
                publicationDate: "2000",
                languageCode: "en",
                pageCount: 100,
                physicalAttributes: [.illustrated]
            )
        )
        let missing = CatalogItem(source: SourceFileMetadata(relativePath: "Missing.jpg"))
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [missing, newer, older])
        store.filter = .all

        store.sortOption = .publicationYear
        XCTAssertEqual(store.visibleItems.map(\.id), [older.id, newer.id, missing.id])

        store.sortOption = .language
        XCTAssertEqual(store.visibleItems.map(\.id), [newer.id, older.id, missing.id])

        store.sortOption = .pageCount
        XCTAssertEqual(store.visibleItems.map(\.id), [newer.id, older.id, missing.id])

        store.sortOption = .physicalAttributes
        XCTAssertEqual(store.visibleItems.last?.id, missing.id)
        XCTAssertEqual(Set(store.visibleItems.dropLast().map(\.id)), [newer.id, older.id])
    }

    func testPublicationYearFiltersRequireTheSameParseableYearUsedBySorting() {
        let unparseable = CatalogItem(
            source: SourceFileMetadata(relativePath: "Undated.jpg"),
            bibliography: BibliographicMetadata(publicationDate: "Undated reprint")
        )
        let dated = CatalogItem(
            source: SourceFileMetadata(relativePath: "Dated.jpg"),
            bibliography: BibliographicMetadata(publicationDate: "2000")
        )
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [unparseable, dated])
        store.filter = .all

        store.sortOption = .publicationYear
        XCTAssertEqual(store.visibleItems.map(\.id), [dated.id, unparseable.id])

        store.filter = .hasPublicationYear
        XCTAssertEqual(store.visibleItems.map(\.id), [dated.id])

        store.filter = .missingPublicationYear
        XCTAssertEqual(store.visibleItems.map(\.id), [unparseable.id])
    }

    func testLanguageSortUsesAdditionalLanguageCodesForEligibility() {
        let missing = CatalogItem(source: SourceFileMetadata(relativePath: "Missing.jpg"))
        let additional = CatalogItem(
            source: SourceFileMetadata(relativePath: "Additional.jpg"),
            bibliography: BibliographicMetadata(additionalLanguageCodes: ["fr"])
        )
        let primary = CatalogItem(
            source: SourceFileMetadata(relativePath: "Primary.jpg"),
            bibliography: BibliographicMetadata(languageCode: "en")
        )
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [missing, additional, primary])
        store.filter = .all
        store.sortOption = .language

        XCTAssertEqual(store.visibleItems.map(\.id), [primary.id, additional.id, missing.id])

        store.filter = .hasLanguage
        XCTAssertEqual(store.visibleItems.map(\.id), [primary.id, additional.id])
    }
}
