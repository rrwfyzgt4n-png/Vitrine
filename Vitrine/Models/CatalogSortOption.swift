import Foundation

enum CatalogSortOption: String, CaseIterable, Identifiable, Sendable {
    case titleAscending
    case titleDescending
    case author
    case filename
    case publisher
    case collection
    case dateAdded
    case coverFileModified
    case recentlyUpdated

    var id: Self { self }

    var label: String {
        switch self {
        case .titleAscending: L10n.text("Title A–Z")
        case .titleDescending: L10n.text("Title Z–A")
        case .author: L10n.text("Author")
        case .filename: L10n.text("Filename")
        case .publisher: L10n.text("Publisher")
        case .collection: L10n.text("Collection")
        case .dateAdded: L10n.text("Date Added")
        case .coverFileModified: L10n.text("Cover File Modified")
        case .recentlyUpdated: L10n.text("Recently Updated")
        }
    }

    var systemImage: String {
        switch self {
        case .titleAscending: "textformat.abc"
        case .titleDescending: "textformat.abc"
        case .author: "person"
        case .filename: "doc"
        case .publisher: "building.columns"
        case .collection: "books.vertical"
        case .dateAdded: "calendar.badge.plus"
        case .coverFileModified: "photo.badge.clock"
        case .recentlyUpdated: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }
}
