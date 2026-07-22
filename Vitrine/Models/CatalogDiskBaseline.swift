import Foundation

struct CatalogDiskBaseline: Sendable {
    var fileResourceIdentifier: Data?
    var modificationDate: Date?
    var contentDigest: String
    var parsedCatalog: CatalogSnapshot
}
