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
}
