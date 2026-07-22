import Foundation

enum CatalogReplacementPolicy: Equatable, Sendable {
    case requireMatchingCatalog
    case replaceExistingDestination
}
