import Foundation

enum SuggestionConfidence: String, Sendable {
    case high
    case medium
    case low
}

struct SuggestedValue<Value: Equatable & Sendable>: Equatable, Sendable {
    var value: Value
    var confidence: SuggestionConfidence
    var evidence: String
    var sourceSpan: Range<Int>? = nil
}

struct FilenameMetadataSuggestion: Equatable, Sendable {
    var title: SuggestedValue<String>?
    var subtitle: SuggestedValue<String>?
    var authors: SuggestedValue<[String]>?
    var translators: SuggestedValue<[String]>?
    var contributors: SuggestedValue<[BibliographicContributor]>?
    var publisher: SuggestedValue<String>?
    var collectionName: SuggestedValue<String>?
    var collectionNumber: SuggestedValue<String>?
    var publicationPlace: SuggestedValue<String>?
    var publicationDate: SuggestedValue<String>?
    var originalPublicationDate: SuggestedValue<String>?
    var editionDescription: SuggestedValue<String>?
    var volumeDescription: SuggestedValue<String>?
    var languageCodes: SuggestedValue<[String]>?
    var originalLanguageCode: SuggestedValue<String>?
    var pageCount: SuggestedValue<Int>?
    var paginationStatus: SuggestedValue<PaginationStatus>?
    var physicalAttributes: SuggestedValue<[PhysicalAttribute]>?
    var descriptiveNotes: SuggestedValue<String>?
}
