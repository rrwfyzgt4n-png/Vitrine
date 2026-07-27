import Foundation

enum CatalogFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case coversAvailable
    case coverNotFound
    case needsReview
    case missingISBN
    case hasISBN
    case detailsAdded
    case noDetails
    case hasPublicationYear
    case missingPublicationYear
    case hasLanguage
    case missingLanguage
    case hasPageCount
    case missingPageCount
    case hasPhysicalAttributes
    case missingPhysicalAttributes

    var id: Self { self }

    var label: String {
        switch self {
        case .all: L10n.text("All Books")
        case .coversAvailable: L10n.text("Covers Available")
        case .coverNotFound: L10n.text("Cover Not Found")
        case .needsReview: L10n.text("Filename Not Reviewed")
        case .missingISBN: L10n.text("Missing ISBN")
        case .hasISBN: L10n.text("Has ISBN")
        case .detailsAdded: L10n.text("Book Details Added")
        case .noDetails: L10n.text("No Book Details")
        case .hasPublicationYear: L10n.text("Has Publication Year")
        case .missingPublicationYear: L10n.text("Missing Publication Year")
        case .hasLanguage: L10n.text("Has Language")
        case .missingLanguage: L10n.text("Missing Language")
        case .hasPageCount: L10n.text("Has Page Count")
        case .missingPageCount: L10n.text("Missing Page Count")
        case .hasPhysicalAttributes: L10n.text("Has Physical Attributes")
        case .missingPhysicalAttributes: L10n.text("Missing Physical Attributes")
        }
    }

    var systemImage: String {
        switch self {
        case .all: "books.vertical"
        case .coversAvailable: "photo"
        case .coverNotFound: "photo.badge.exclamationmark"
        case .needsReview: "text.magnifyingglass"
        case .missingISBN: "barcode.viewfinder"
        case .hasISBN: "barcode"
        case .detailsAdded: "checkmark.circle"
        case .noDetails: "circle.dashed"
        case .hasPublicationYear: "calendar"
        case .missingPublicationYear: "calendar.badge.exclamationmark"
        case .hasLanguage: "character.book.closed"
        case .missingLanguage: "character.book.closed.fill"
        case .hasPageCount: "number.square"
        case .missingPageCount: "number.square.fill"
        case .hasPhysicalAttributes: "list.bullet.rectangle"
        case .missingPhysicalAttributes: "list.bullet.rectangle.fill"
        }
    }
}
