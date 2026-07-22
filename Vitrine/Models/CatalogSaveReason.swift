import Foundation

enum CatalogSaveReason: String, Hashable, Sendable {
    case explicit
    case refresh
    case metadataEdit
    case conflictResolution
    case backupRestore
    case export
}
