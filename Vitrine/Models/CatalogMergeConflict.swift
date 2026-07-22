import Foundation

enum CatalogMergeField: String, CaseIterable, Sendable {
    case catalogName = "Catalog name"
    case sourceFolderName = "Cover folder name"
    case sourceFolderSignature = "Cover folder identity"
    case record = "Book record"
    case source = "Cover file information"
    case isbn10 = "ISBN-10"
    case isbn13 = "ISBN-13"
    case title = "Title"
    case subtitle = "Subtitle"
    case authors = "Authors"
    case translators = "Translators"
    case contributors = "Contributors"
    case publisher = "Publisher"
    case collectionName = "Collection"
    case collectionNumber = "Collection number"
    case publicationPlace = "Publication place"
    case publicationDate = "Publication date"
    case originalPublicationDate = "Original publication date"
    case editionDescription = "Edition"
    case volumeDescription = "Volume"
    case languageCode = "Language"
    case additionalLanguageCodes = "Additional languages"
    case originalLanguageCode = "Original language"
    case pageCount = "Page count"
    case paginationStatus = "Pagination"
    case physicalAttributes = "Physical attributes"
    case subjects = "Subjects"
    case description = "Description"
    case openLibraryEditionID = "Open Library edition"
    case openLibraryWorkID = "Open Library work"
    case metadataSource = "Metadata source"
    case metadataRetrievedAt = "Metadata retrieval date"
    case metadataConfirmedByUser = "Metadata confirmation"
    case personalNotes = "Personal notes"
    case availability = "Cover availability"
    case unrecognizedLines = "Unrecognized catalog data"
}

struct CatalogMergeConflict: Identifiable, Equatable, Sendable {
    var id = UUID()
    var recordID: UUID?
    var bookTitle: String?
    var field: CatalogMergeField
    var localValue: String
    var externalValue: String
}

struct PendingCatalogMerge: Equatable, Sendable {
    var merged: CatalogSnapshot
    var external: CatalogSnapshot
    var conflicts: [CatalogMergeConflict]
}
