import SwiftUI

struct AboutVitrineView: View {
    let store: CatalogStore

    @AppStorage("aboutComparisonBookIndex") private var comparisonBookIndex = -1

    private var statistics: LibraryStatistics? {
        store.catalog.map { LibraryStatistics(items: $0.items) }
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("About Vitrine")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .contentShape(.rect)
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents(true)

            BreathingAppIconView()

            VStack(spacing: 4) {
                Text("Vitrine")
                    .font(.largeTitle.bold())
                Text(versionDescription)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let statistics {
                libraryStatistics(statistics)
            } else {
                ContentUnavailableView(
                    "No Library Open",
                    systemImage: "books.vertical",
                    description: Text("Open a catalog to see its page total and rotating book comparison.")
                )
            }

        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .frame(width: 560, height: 520, alignment: .top)
        .windowMinimizeBehavior(.disabled)
    }

    private func libraryStatistics(_ statistics: LibraryStatistics) -> some View {
        VStack(spacing: 10) {
            Text("Library Statistics")
                .font(.title3.bold())

            Text(String(localized: "This library contains \(statistics.cataloguedPageCount) catalogued pages."))
                .font(.headline)

            if statistics.booksWithPageCounts < statistics.bookCount {
                Text(String(localized: "Page counts are available for \(statistics.booksWithPageCounts) of \(statistics.bookCount) books."))
                    .foregroundStyle(.secondary)
            }

            if let comparisonText = catalogComparisonText(statistics) {
                Text(comparisonText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: 520)
    }

    private func catalogComparisonText(_ statistics: LibraryStatistics) -> String? {
        guard let catalog = store.catalog else { return nil }
        let eligibleBooks = catalog.items.compactMap { item -> (title: String, author: String?, pageCount: Int)? in
            guard let pageCount = item.bibliography.pageCount, pageCount > 0 else { return nil }
            return (item.displayTitle, item.displayAuthor, pageCount)
        }
        guard !eligibleBooks.isEmpty else { return nil }

        let bookIndex = max(0, comparisonBookIndex) % eligibleBooks.count
        let selectedBook = eligibleBooks[bookIndex]
        let representationFactor = Int(ceil(Double(statistics.cataloguedPageCount) / Double(selectedBook.pageCount)))

        if let author = selectedBook.author {
            return String(localized: "Its \(statistics.bookCount) books total about the same number of pages as \(representationFactor) copies of \(selectedBook.title) by \(author).")
        }
        return String(localized: "Its \(statistics.bookCount) books total about the same number of pages as \(representationFactor) copies of \(selectedBook.title).")
    }

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return String(localized: "Version \(version) (\(build))")
    }
}
