import Foundation

struct GutenbergCatalogReference: Equatable, Sendable {
    var eBookCount: Int
    var asOfYear: Int
    var asOfMonth: Int
    var sourceURL: URL
}

struct LibraryStatistics: Equatable, Sendable {
    static let gutenbergReference = GutenbergCatalogReference(
        eBookCount: 77_687,
        asOfYear: 2026,
        asOfMonth: 7,
        sourceURL: URL(string: "https://www.gutenberg.org/")!
    )

    static var gutenbergBookCount: Int {
        gutenbergReference.eBookCount
    }

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
