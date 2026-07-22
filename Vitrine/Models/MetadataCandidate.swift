import Foundation

enum MetadataLookupQuery: Hashable, Sendable {
    case isbn(String)
    case titleAuthor(title: String, author: String?)
}

struct MetadataCandidate: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var subtitle: String?
    var authors: [String]
    var publisher: String?
    var publicationDate: String?
    var originalPublicationDate: String?
    var pageCount: Int?
    var languageCodes: [String]
    var subjects: [String]
    var isbn10: String?
    var isbn13: String?
    var openLibraryWorkID: String?
    var openLibraryEditionID: String?
}

enum MetadataCandidateField: String, CaseIterable, Hashable, Sendable {
    case title, subtitle, authors, publisher, publicationDate, originalPublicationDate
    case pageCount, language, subjects, isbn10, isbn13
}
