import Foundation

/// Integrates reviewed parser output with the durable catalog model.
/// Parsing remains independent; this adapter is the only parser-to-catalog mapping surface.
struct FilenameMetadataSuggestionAdapter: Sendable {
    func applying(
        _ suggestion: FilenameMetadataSuggestion,
        to original: CatalogItem
    ) -> CatalogItem {
        var item = original
        if let value = suggestion.title?.value { item.bibliography.title = value }
        if let value = suggestion.subtitle?.value { item.bibliography.subtitle = value }
        if let value = suggestion.authors?.value { item.bibliography.authors = value }
        if let value = suggestion.translators?.value { item.bibliography.translators = value }
        if let value = suggestion.contributors?.value { item.bibliography.contributors = value }
        if let value = suggestion.publisher?.value { item.bibliography.publisher = value }
        if let value = suggestion.collectionName?.value { item.bibliography.collectionName = value }
        if let value = suggestion.collectionNumber?.value { item.bibliography.collectionNumber = value }
        if let value = suggestion.publicationPlace?.value { item.bibliography.publicationPlace = value }
        if let value = suggestion.publicationDate?.value { item.bibliography.publicationDate = value }
        if let value = suggestion.originalPublicationDate?.value { item.bibliography.originalPublicationDate = value }
        if let value = suggestion.editionDescription?.value { item.bibliography.editionDescription = value }
        if let value = suggestion.volumeDescription?.value { item.bibliography.volumeDescription = value }
        if let value = suggestion.languageCodes?.value, let primary = value.first {
            item.bibliography.languageCode = primary
            item.bibliography.additionalLanguageCodes = Array(value.dropFirst())
        }
        if let value = suggestion.originalLanguageCode?.value { item.bibliography.originalLanguageCode = value }
        if let value = suggestion.pageCount?.value { item.bibliography.pageCount = value }
        if let value = suggestion.paginationStatus?.value { item.bibliography.paginationStatus = value }
        if let value = suggestion.physicalAttributes?.value { item.bibliography.physicalAttributes = value }
        if let value = suggestion.descriptiveNotes?.value { item.bibliography.description = value }
        item.bibliography.metadataSource = provenance(
            adding: .filename,
            to: item.bibliography.metadataSource
        )
        item.bibliography.metadataConfirmedByUser = true
        return item
    }

    private func provenance(
        adding source: MetadataSource,
        to existing: MetadataSource?
    ) -> MetadataSource {
        guard let existing else { return source }
        return existing == source ? source : .mixed
    }
}
