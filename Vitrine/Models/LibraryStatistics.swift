import Foundation

struct LibraryStatistics: Equatable, Sendable {
    static let gutenbergBookCount = 77_687

    var bookCount: Int
    var cataloguedPageCount: Int
    var booksWithPageCounts: Int

    init(items: [CatalogItem]) {
        bookCount = items.count
        let pageCounts = items.compactMap { item -> Int? in
            guard let count = item.bibliography.pageCount, count > 0 else { return nil }
            return count
        }
        cataloguedPageCount = pageCounts.reduce(0, +)
        booksWithPageCounts = pageCounts.count
    }

    var gutenbergBookShare: Double {
        guard bookCount > 0 else { return 0 }
        return Double(bookCount) / Double(Self.gutenbergBookCount)
    }
}
