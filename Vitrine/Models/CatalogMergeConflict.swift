import Foundation

enum CatalogMergeField: String, CaseIterable, Hashable, Sendable {
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

    var label: String {
        switch self {
        case .catalogName: L10n.text("Catalog name")
        case .sourceFolderName: L10n.text("Cover folder name")
        case .sourceFolderSignature: L10n.text("Cover folder identity")
        case .record: L10n.text("Book record")
        case .source: L10n.text("Cover file information")
        case .isbn10: L10n.text("ISBN-10")
        case .isbn13: L10n.text("ISBN-13")
        case .title: L10n.text("Title")
        case .subtitle: L10n.text("Subtitle")
        case .authors: L10n.text("Authors")
        case .translators: L10n.text("Translators")
        case .contributors: L10n.text("Contributors")
        case .publisher: L10n.text("Publisher")
        case .collectionName: L10n.text("Collection")
        case .collectionNumber: L10n.text("Collection number")
        case .publicationPlace: L10n.text("Publication place")
        case .publicationDate: L10n.text("Publication date")
        case .originalPublicationDate: L10n.text("Original publication date")
        case .editionDescription: L10n.text("Edition")
        case .volumeDescription: L10n.text("Volume")
        case .languageCode: L10n.text("Language")
        case .additionalLanguageCodes: L10n.text("Additional languages")
        case .originalLanguageCode: L10n.text("Original language")
        case .pageCount: L10n.text("Page count")
        case .paginationStatus: L10n.text("Pagination")
        case .physicalAttributes: L10n.text("Physical attributes")
        case .subjects: L10n.text("Subjects")
        case .description: L10n.text("Description")
        case .openLibraryEditionID: L10n.text("Open Library edition")
        case .openLibraryWorkID: L10n.text("Open Library work")
        case .metadataSource: L10n.text("Metadata source")
        case .metadataRetrievedAt: L10n.text("Metadata retrieval date")
        case .metadataConfirmedByUser: L10n.text("Metadata confirmation")
        case .personalNotes: L10n.text("Personal notes")
        case .availability: L10n.text("Cover availability")
        case .unrecognizedLines: L10n.text("Unrecognized catalog data")
        }
    }
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
