import Foundation

struct CatalogItem: Identifiable, Equatable, Sendable {
    var id: UUID
    var source: SourceFileMetadata
    var bibliography: BibliographicMetadata
    var personalNotes: String
    var dateAdded: Date
    var dateModified: Date
    var availability: ItemAvailability
    var unrecognizedLines: [String]

    init(
        id: UUID = UUID(),
        source: SourceFileMetadata,
        bibliography: BibliographicMetadata = .init(),
        personalNotes: String = "",
        dateAdded: Date = .now,
        dateModified: Date = .now,
        availability: ItemAvailability = .available,
        unrecognizedLines: [String] = []
    ) {
        self.id = id
        self.source = source
        self.bibliography = bibliography
        self.personalNotes = personalNotes
        self.dateAdded = dateAdded
        self.dateModified = dateModified
        self.availability = availability
        self.unrecognizedLines = unrecognizedLines
    }

    var displayTitle: String {
        if bibliography.metadataConfirmedByUser,
           let title = bibliography.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        return source.sourceTitle
    }

    var displayAuthor: String? {
        let value = bibliography.authors.joined(separator: ", ")
        return value.isEmpty ? nil : value
    }
}
