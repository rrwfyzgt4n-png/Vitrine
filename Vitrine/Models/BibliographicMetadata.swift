import Foundation

enum ContributorRole: String, CaseIterable, Equatable, Sendable {
    case editor
    case compiler
    case annotator
    case generalEditor = "general-editor"
    case editorDirector = "editor-director"
    case preface
    case foreword
    case introduction
    case illustrator
    case iconographer
    case cartographer
    case assistant
    case collaborator

    var label: String {
        switch self {
        case .editor: L10n.text("Editor")
        case .compiler: L10n.text("Compiler")
        case .annotator: L10n.text("Annotator")
        case .generalEditor: L10n.text("General editor")
        case .editorDirector: L10n.text("Editor/director")
        case .preface: L10n.text("Preface")
        case .foreword: L10n.text("Foreword")
        case .introduction: L10n.text("Introduction")
        case .illustrator: L10n.text("Illustrator")
        case .iconographer: L10n.text("Iconographer")
        case .cartographer: L10n.text("Cartographer")
        case .assistant: L10n.text("Assistant")
        case .collaborator: L10n.text("Collaborator")
        }
    }
}

struct BibliographicContributor: Equatable, Sendable {
    var name: String
    var roles: [ContributorRole]
}

enum PaginationStatus: String, CaseIterable, Equatable, Sendable {
    case nonPaginated = "non-paginated"

    var label: String {
        switch self {
        case .nonPaginated: L10n.text("Non-paginated")
        }
    }
}

enum PhysicalAttribute: String, CaseIterable, Equatable, Sendable {
    case illustrated
    case maps
    case foldoutMaps = "foldout-maps"
    case battlePlans = "battle-plans"
    case genealogicalTrees = "genealogical-trees"
    case blackAndWhite = "black-and-white"
    case dustJacket = "dust-jacket"
    case slipcase
    case doublePages = "double-pages"

    var label: String {
        switch self {
        case .illustrated: L10n.text("Illustrated")
        case .maps: L10n.text("Maps")
        case .foldoutMaps: L10n.text("Fold-out maps")
        case .battlePlans: L10n.text("Battle plans")
        case .genealogicalTrees: L10n.text("Genealogical trees")
        case .blackAndWhite: L10n.text("Black and white")
        case .dustJacket: L10n.text("Dust jacket")
        case .slipcase: L10n.text("Slipcase")
        case .doublePages: L10n.text("Double pages")
        }
    }
}

struct BibliographicMetadata: Equatable, Sendable {
    var isbn10: String?
    var isbn13: String?
    var title: String?
    var subtitle: String?
    var authors: [String]
    var translators: [String]
    var contributors: [BibliographicContributor]
    var publisher: String?
    var collectionName: String?
    var collectionNumber: String?
    var publicationPlace: String?
    var publicationDate: String?
    var originalPublicationDate: String?
    var editionDescription: String?
    var volumeDescription: String?
    var languageCode: String?
    var additionalLanguageCodes: [String]
    var originalLanguageCode: String?
    var pageCount: Int?
    var paginationStatus: PaginationStatus?
    var physicalAttributes: [PhysicalAttribute]
    var subjects: [String]
    var description: String?
    var openLibraryEditionID: String?
    var openLibraryWorkID: String?
    var metadataSource: MetadataSource?
    var metadataRetrievedAt: Date?
    var metadataConfirmedByUser: Bool

    init(
        isbn10: String? = nil,
        isbn13: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        authors: [String] = [],
        translators: [String] = [],
        contributors: [BibliographicContributor] = [],
        publisher: String? = nil,
        collectionName: String? = nil,
        collectionNumber: String? = nil,
        publicationPlace: String? = nil,
        publicationDate: String? = nil,
        originalPublicationDate: String? = nil,
        editionDescription: String? = nil,
        volumeDescription: String? = nil,
        languageCode: String? = nil,
        additionalLanguageCodes: [String] = [],
        originalLanguageCode: String? = nil,
        pageCount: Int? = nil,
        paginationStatus: PaginationStatus? = nil,
        physicalAttributes: [PhysicalAttribute] = [],
        subjects: [String] = [],
        description: String? = nil,
        openLibraryEditionID: String? = nil,
        openLibraryWorkID: String? = nil,
        metadataSource: MetadataSource? = nil,
        metadataRetrievedAt: Date? = nil,
        metadataConfirmedByUser: Bool = false
    ) {
        self.isbn10 = isbn10
        self.isbn13 = isbn13
        self.title = title
        self.subtitle = subtitle
        self.authors = authors
        self.translators = translators
        self.contributors = contributors
        self.publisher = publisher
        self.collectionName = collectionName
        self.collectionNumber = collectionNumber
        self.publicationPlace = publicationPlace
        self.publicationDate = publicationDate
        self.originalPublicationDate = originalPublicationDate
        self.editionDescription = editionDescription
        self.volumeDescription = volumeDescription
        self.languageCode = languageCode
        self.additionalLanguageCodes = additionalLanguageCodes
        self.originalLanguageCode = originalLanguageCode
        self.pageCount = pageCount
        self.paginationStatus = paginationStatus
        self.physicalAttributes = physicalAttributes
        self.subjects = subjects
        self.description = description
        self.openLibraryEditionID = openLibraryEditionID
        self.openLibraryWorkID = openLibraryWorkID
        self.metadataSource = metadataSource
        self.metadataRetrievedAt = metadataRetrievedAt
        self.metadataConfirmedByUser = metadataConfirmedByUser
    }
}

/// Executable inventory of the durable bibliographic schema. Tests compare this
/// registry with the model, Markdown round trip, and merge surface so adding a
/// stored field cannot silently omit an integration boundary.
enum BibliographicMetadataField: String, CaseIterable, Sendable {
    case isbn10, isbn13, title, subtitle, authors, translators, contributors
    case publisher, collectionName, collectionNumber, publicationPlace
    case publicationDate, originalPublicationDate, editionDescription, volumeDescription
    case languageCode, additionalLanguageCodes, originalLanguageCode
    case pageCount, paginationStatus, physicalAttributes, subjects, description
    case openLibraryEditionID, openLibraryWorkID, metadataSource, metadataRetrievedAt
    case metadataConfirmedByUser

    var markdownKeys: [String] {
        switch self {
        case .isbn10: ["isbn-10"]
        case .isbn13: ["isbn-13"]
        case .title: ["bibliographic-title"]
        case .subtitle: ["subtitle"]
        case .authors: ["author"]
        case .translators: ["translator"]
        case .contributors: ["contributor"]
        case .publisher: ["publisher"]
        case .collectionName: ["collection"]
        case .collectionNumber: ["collection-number"]
        case .publicationPlace: ["publication-place"]
        case .publicationDate: ["published"]
        case .originalPublicationDate: ["original-published"]
        case .editionDescription: ["edition"]
        case .volumeDescription: ["volume"]
        case .languageCode: ["language"]
        case .additionalLanguageCodes: ["additional-language"]
        case .originalLanguageCode: ["original-language"]
        case .pageCount: ["pages"]
        case .paginationStatus: ["pagination"]
        case .physicalAttributes: ["physical-attribute"]
        case .subjects: ["subject"]
        case .description: ["description"]
        case .openLibraryEditionID: ["open-library-edition-id"]
        case .openLibraryWorkID: ["open-library-work-id"]
        case .metadataSource: ["metadata-source"]
        case .metadataRetrievedAt: ["metadata-retrieved"]
        case .metadataConfirmedByUser: ["metadata-confirmed"]
        }
    }

    var mergeField: CatalogMergeField {
        switch self {
        case .isbn10: .isbn10
        case .isbn13: .isbn13
        case .title: .title
        case .subtitle: .subtitle
        case .authors: .authors
        case .translators: .translators
        case .contributors: .contributors
        case .publisher: .publisher
        case .collectionName: .collectionName
        case .collectionNumber: .collectionNumber
        case .publicationPlace: .publicationPlace
        case .publicationDate: .publicationDate
        case .originalPublicationDate: .originalPublicationDate
        case .editionDescription: .editionDescription
        case .volumeDescription: .volumeDescription
        case .languageCode: .languageCode
        case .additionalLanguageCodes: .additionalLanguageCodes
        case .originalLanguageCode: .originalLanguageCode
        case .pageCount: .pageCount
        case .paginationStatus: .paginationStatus
        case .physicalAttributes: .physicalAttributes
        case .subjects: .subjects
        case .description: .description
        case .openLibraryEditionID: .openLibraryEditionID
        case .openLibraryWorkID: .openLibraryWorkID
        case .metadataSource: .metadataSource
        case .metadataRetrievedAt: .metadataRetrievedAt
        case .metadataConfirmedByUser: .metadataConfirmedByUser
        }
    }
}
