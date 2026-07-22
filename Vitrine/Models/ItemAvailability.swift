import Foundation

enum ItemAvailability: String, Codable, CaseIterable, Sendable {
    case available
    case temporarilyUnavailable
    case missing
    case ambiguousMatch
    case metadataOnly
}
