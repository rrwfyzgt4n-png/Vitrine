import Foundation

struct CatalogScanResult: Sendable {
    var sources: [SourceFileMetadata]
    var completedEnumeration: Bool
    var warnings: [CatalogScanWarning]
}

struct CatalogScanWarning: Identifiable, Sendable {
    let id = UUID()
    var relativePath: String
    var message: String
}
