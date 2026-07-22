import AppKit
import SwiftUI

struct AboutVitrineView: View {
    let store: CatalogStore

    private var statistics: LibraryStatistics? {
        store.catalog.map { LibraryStatistics(items: $0.items) }
    }

    var body: some View {
        VStack(spacing: 18) {
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
                    description: Text("Open a catalog to see its page total and Project Gutenberg comparison.")
                )
            }

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(width: 620, height: 690)
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

            Text(String(localized: "Its \(statistics.bookCount) books represent \(gutenbergShare(statistics)) of Project Gutenberg's \(LibraryStatistics.gutenbergBookCount) eBooks."))
                .multilineTextAlignment(.center)

            Text("Project Gutenberg reports an eBook count, not a universal page count. Reference: July 2026.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Link("View Project Gutenberg", destination: URL(string: "https://www.gutenberg.org/")!)
                .font(.caption)
        }
        .frame(maxWidth: 520)
    }

    private func gutenbergShare(_ statistics: LibraryStatistics) -> String {
        statistics.gutenbergBookShare.formatted(
            .percent.precision(.fractionLength(3))
        )
    }

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return String(localized: "Version \(version) (\(build))")
    }
}
