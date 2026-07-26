import Foundation

/// Transient, main-actor-owned search and sort data. The catalog remains the
/// source of truth; this index is discarded whenever a catalog snapshot changes.
struct CatalogDerivedIndex {
    struct Entry {
        var searchableText: String?
        var title: String?
        var author: String?
        var publisher: String?
        var collection: String?
    }

    private var entries: [CatalogItem.ID: Entry] = [:]

    mutating func removeAll() {
        entries.removeAll(keepingCapacity: true)
    }

    mutating func prepare(
        for items: [CatalogItem],
        sortOption: CatalogSortOption,
        includingSearchText: Bool
    ) {
        guard entries.count != items.count ||
                items.contains(where: { entries[$0.id] == nil }) ||
                items.contains(where: { needsSortKey(sortOption, entry: entries[$0.id]) }) ||
                (includingSearchText && items.contains(where: {
                    entries[$0.id]?.searchableText == nil
                })) else {
            return
        }

        entries.reserveCapacity(items.count)
        for item in items {
            var entry = entries[item.id] ?? Entry(
                searchableText: nil,
                title: nil,
                author: nil,
                publisher: nil,
                collection: nil
            )
            if includingSearchText, entry.searchableText == nil {
                entry.searchableText = Self.searchableText(for: item)
            }
            switch sortOption {
            case .titleAscending, .titleDescending:
                entry.title = entry.title ?? SearchNormalizer.normalize(item.displayTitle)
            case .author:
                entry.author = entry.author ??
                    SearchNormalizer.normalize(item.displayAuthor ?? item.displayTitle)
            case .publisher:
                entry.publisher = entry.publisher ??
                    SearchNormalizer.normalize(item.bibliography.publisher ?? item.displayTitle)
            case .collection:
                entry.collection = entry.collection ??
                    SearchNormalizer.normalize(item.bibliography.collectionName ?? item.displayTitle)
            case .filename, .dateAdded, .coverFileModified, .recentlyUpdated:
                break
            }
            entries[item.id] = entry
        }
    }

    func entry(for itemID: CatalogItem.ID) -> Entry? {
        entries[itemID]
    }

    private func needsSortKey(
        _ sortOption: CatalogSortOption,
        entry: Entry?
    ) -> Bool {
        guard let entry else { return true }
        return switch sortOption {
        case .titleAscending, .titleDescending: entry.title == nil
        case .author: entry.author == nil
        case .publisher: entry.publisher == nil
        case .collection: entry.collection == nil
        case .filename, .dateAdded, .coverFileModified, .recentlyUpdated: false
        }
    }

    private static func searchableText(for item: CatalogItem) -> String {
        let bibliography = item.bibliography
        let scalarValues: [String?] = [
            item.source.sourceTitle, item.source.filename, item.source.finderComment,
            bibliography.title, bibliography.subtitle, bibliography.isbn10, bibliography.isbn13,
            bibliography.publisher, bibliography.collectionName, bibliography.collectionNumber, bibliography.publicationPlace,
            bibliography.publicationDate, bibliography.originalPublicationDate, bibliography.editionDescription,
            bibliography.volumeDescription, bibliography.languageCode, bibliography.originalLanguageCode,
            bibliography.paginationStatus?.label, bibliography.paginationStatus?.rawValue,
            bibliography.description, item.personalNotes,
        ]
        var values = scalarValues.compactMap { $0 }
        values.append(contentsOf: bibliography.authors)
        values.append(contentsOf: bibliography.translators)
        values.append(contentsOf: bibliography.contributors.map(\.name))
        let contributorRoles = bibliography.contributors.flatMap(\.roles)
        values.append(contentsOf: contributorRoles.map(\.label))
        values.append(contentsOf: contributorRoles.map(\.rawValue))
        values.append(contentsOf: bibliography.additionalLanguageCodes)
        values.append(contentsOf: bibliography.physicalAttributes.map(\.label))
        values.append(contentsOf: bibliography.physicalAttributes.map(\.rawValue))
        values.append(contentsOf: bibliography.subjects)
        return SearchNormalizer.normalize(values.joined(separator: " "))
    }
}
