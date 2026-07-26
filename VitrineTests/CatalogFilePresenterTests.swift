import XCTest
@testable import Vitrine

final class CatalogFilePresenterTests: XCTestCase {
    func testPresenterCallbacksAreIsolatedIntoTypedEvents() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "Catalog-\(UUID().uuidString).md")
        let presenter = CatalogFilePresenter(url: url)
        defer { presenter.stop() }
        var iterator = presenter.events.makeAsyncIterator()

        presenter.presentedItemDidChange()
        presenter.presentedItemDidMove(to: url.appendingPathExtension("moved"))

        let changed = await iterator.next()
        let moved = await iterator.next()
        XCTAssertEqual(changed, .changed)
        XCTAssertEqual(moved, .moved(url.appendingPathExtension("moved")))
    }

    func testRelinquishmentCompletesWithoutReportingVitrinesOwnAccessAsAChange() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "Catalog-\(UUID().uuidString).md")
        let presenter = CatalogFilePresenter(url: url)
        defer { presenter.stop() }
        var iterator = presenter.events.makeAsyncIterator()
        let reacquirerSupplied = expectation(description: "Reacquirer supplied")

        presenter.relinquishPresentedItem(toWriter: { suppliedReacquirer in
            if suppliedReacquirer != nil { reacquirerSupplied.fulfill() }
            suppliedReacquirer?()
        })

        await fulfillment(of: [reacquirerSupplied], timeout: 0.5)
        presenter.presentedItemDidChange()
        let nextEvent = await iterator.next()
        XCTAssertEqual(nextEvent, .changed)
    }

    func testDeletionAccommodationNeverBlocksTheCoordinator() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "Catalog-\(UUID().uuidString).md")
        let presenter = CatalogFilePresenter(url: url)
        defer { presenter.stop() }
        var iterator = presenter.events.makeAsyncIterator()
        let completion = expectation(description: "Deletion accommodation completed")

        presenter.accommodatePresentedItemDeletion { error in
            XCTAssertNil(error)
            completion.fulfill()
        }

        await fulfillment(of: [completion], timeout: 0.5)
        let deleted = await iterator.next()
        XCTAssertEqual(deleted, .deleted)
    }

    func testRapidEventsRemainOrderedUntilTheStoreCanRereadState() async {
        let url = FileManager.default.temporaryDirectory.appending(path: "Catalog-\(UUID().uuidString).md")
        let presenter = CatalogFilePresenter(url: url)
        defer { presenter.stop() }
        var iterator = presenter.events.makeAsyncIterator()

        for index in 0..<20 {
            presenter.presentedItemDidMove(to: url.appendingPathExtension("\(index)"))
        }

        for index in 0..<20 {
            let event = await iterator.next()
            XCTAssertEqual(event, .moved(url.appendingPathExtension("\(index)")))
        }
    }
}
