import XCTest
@testable import Vitrine

final class LibraryStatisticsTests: XCTestCase {
    func testStatisticsSumOnlyKnownPositivePageCounts() {
        let items = [
            item(pageCount: 240),
            item(pageCount: nil),
            item(pageCount: 360),
            item(pageCount: 0),
        ]

        let statistics = LibraryStatistics(items: items)

        XCTAssertEqual(statistics.bookCount, 4)
        XCTAssertEqual(statistics.cataloguedPageCount, 600)
        XCTAssertEqual(statistics.booksWithPageCounts, 2)
    }

    func testGutenbergShareUsesPublishedBookCount() {
        let items = (0..<66).map { _ in item(pageCount: 200) }
        let statistics = LibraryStatistics(items: items)

        XCTAssertEqual(LibraryStatistics.gutenbergBookCount, 77_687)
        XCTAssertEqual(
            statistics.gutenbergBookShare,
            Double(66) / Double(77_687),
            accuracy: 0.000_000_001
        )
    }

    private func item(pageCount: Int?) -> CatalogItem {
        CatalogItem(
            source: SourceFileMetadata(relativePath: "\(UUID().uuidString).jpg"),
            bibliography: BibliographicMetadata(pageCount: pageCount)
        )
    }
}
