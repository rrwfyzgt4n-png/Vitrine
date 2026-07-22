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

    func testClearingNeedsReviewFilterRestoresAvailableBooks() {
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
                CatalogItem(source: SourceFileMetadata(relativePath: "Available.jpg")),
                CatalogItem(
                    source: SourceFileMetadata(relativePath: "Ambiguous.jpg"),
                    availability: .ambiguousMatch
                ),
            ]
        )

        store.filter = .needsReview
        XCTAssertEqual(store.visibleItems.map(\.source.filename), ["Ambiguous.jpg"])

        store.filter = .all
        XCTAssertEqual(Set(store.visibleItems.map(\.source.filename)), ["Available.jpg", "Ambiguous.jpg"])
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
}
