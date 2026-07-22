import Foundation

enum MetadataSource: String, Codable, Sendable {
    case filename
    case manual
    case openLibrary = "open-library"
    case mixed
}
