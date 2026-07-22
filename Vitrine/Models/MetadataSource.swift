import Foundation

enum MetadataSource: String, Codable, Sendable {
    case filename
    case manual
    case openLibrary = "open-library"
    case mixed

    var label: String {
        switch self {
        case .filename: L10n.text("Filename suggestion")
        case .manual: L10n.text("Entered manually")
        case .openLibrary: "Open Library"
        case .mixed: L10n.text("Multiple sources")
        }
    }
}
