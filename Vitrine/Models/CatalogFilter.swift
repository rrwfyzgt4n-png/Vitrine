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
        }
    }
}
