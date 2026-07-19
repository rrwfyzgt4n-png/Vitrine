import Foundation

struct CatalogReconciliationDiff: Equatable, Sendable {
    var scanID: UUID
    var baseCatalogID: UUID
    var baseCatalogUpdatedAt: Date
    var sourceFolderValidated: Bool
    var scannedSources: [SourceFileMetadata]
    var operations: [CatalogReconciliationOperation]
    var completedEnumeration: Bool
    var warnings: [String]

    init(
        scanID: UUID = UUID(),
        baseCatalogID: UUID,
        baseCatalogUpdatedAt: Date,
        sourceFolderValidated: Bool,
        scannedSources: [SourceFileMetadata],
        operations: [CatalogReconciliationOperation],
        completedEnumeration: Bool,
        warnings: [String]
    ) {
        self.scanID = scanID
        self.baseCatalogID = baseCatalogID
        self.baseCatalogUpdatedAt = baseCatalogUpdatedAt
        self.sourceFolderValidated = sourceFolderValidated
        self.scannedSources = scannedSources
        self.operations = operations
        self.completedEnumeration = completedEnumeration
        self.warnings = warnings
    }
}
