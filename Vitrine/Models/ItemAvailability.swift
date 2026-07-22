import Foundation

enum ItemAvailability: String, Codable, CaseIterable, Sendable {
    case available
    case temporarilyUnavailable
    case missing
    case ambiguousMatch
    case metadataOnly

    var inspectorLabel: String {
        switch self {
        case .available: L10n.text("Available")
        case .temporarilyUnavailable: L10n.text("Temporarily unavailable")
        case .missing: L10n.text("Not found")
        case .ambiguousMatch: L10n.text("Needs review")
        case .metadataOnly: L10n.text("Kept without cover")
        }
    }
}
