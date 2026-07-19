import Foundation

enum ContributorRole: String, CaseIterable, Equatable, Sendable {
    case editor
    case compiler
    case annotator
    case generalEditor = "general-editor"
    case editorDirector = "editor-director"
    case preface
    case foreword
    case illustrator
    case iconographer
    case cartographer
    case assistant

    var label: String {
        switch self {
        case .editor: "Editor"
        case .compiler: "Compiler"
        case .annotator: "Annotator"
        case .generalEditor: "General editor"
        case .editorDirector: "Editor/director"
        case .preface: "Preface"
        case .foreword: "Foreword"
        case .illustrator: "Illustrator"
        case .iconographer: "Iconographer"
        case .cartographer: "Cartographer"
        case .assistant: "Assistant"
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
        case .nonPaginated: "Non-paginated"
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
        case .illustrated: "Illustrated"
        case .maps: "Maps"
        case .foldoutMaps: "Fold-out maps"
        case .battlePlans: "Battle plans"
        case .genealogicalTrees: "Genealogical trees"
        case .blackAndWhite: "Black and white"
        case .dustJacket: "Dust jacket"
        case .slipcase: "Slipcase"
        case .doublePages: "Double pages"
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
