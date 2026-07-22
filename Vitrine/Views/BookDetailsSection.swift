import SwiftUI

struct BookDetailsSection: View {
    let item: CatalogItem

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            detail("ISBN", item.bibliography.isbn13 ?? item.bibliography.isbn10)
            detail("ISBN-10", item.bibliography.isbn10)
            detail("ISBN-13", item.bibliography.isbn13)
            detail("Subtitle", item.bibliography.subtitle)
            detail("Contributors", contributors)
            detail("Publisher", item.bibliography.publisher)
            detail("Collection", collection)
            detail("Publication Place", item.bibliography.publicationPlace)
            detail("Published", item.bibliography.publicationDate)
            detail("Originally Published", item.bibliography.originalPublicationDate)
            detail("Edition", item.bibliography.editionDescription)
            detail("Volume", item.bibliography.volumeDescription)
            detail("Translators", item.bibliography.translators.isEmpty ? nil : item.bibliography.translators.joined(separator: ", "))
            detail("Language", languages)
            detail("Original Language", item.bibliography.originalLanguageCode)
            detail("Pages", item.bibliography.pageCount.map(String.init))
            detail("Pagination", item.bibliography.paginationStatus?.label)
            detail("Physical Attributes", BibliographicDisplayFormatter.physicalAttributes(item.bibliography.physicalAttributes))
            detail("Subjects", item.bibliography.subjects.isEmpty ? nil : item.bibliography.subjects.joined(separator: ", "))
            detail("Description", item.bibliography.description)
            detail("Source", metadataSource)
        }
        .padding(.top, 8)
        .accessibilityIdentifier("inspector.bookDetails.content")
    }

    @ViewBuilder
    private func detail(_ label: LocalizedStringKey, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            GridRow {
                Text(label).foregroundStyle(.secondary)
                Text(value)
            }
        }
    }

    private var metadataSource: String? {
        item.bibliography.metadataSource?.label
    }

    private var contributors: String? {
        BibliographicDisplayFormatter.contributors(item.bibliography.contributors)
    }

    private var collection: String? {
        [item.bibliography.collectionName, item.bibliography.collectionNumber]
            .compactMap { $0 }
            .nilIfEmptyJoined(separator: " · ")
    }

    private var languages: String? {
        ([item.bibliography.languageCode].compactMap { $0 } + item.bibliography.additionalLanguageCodes)
            .nilIfEmptyJoined(separator: ", ")
    }
}

private extension [String] {
    func nilIfEmptyJoined(separator: String) -> String? {
        isEmpty ? nil : joined(separator: separator)
    }
}
