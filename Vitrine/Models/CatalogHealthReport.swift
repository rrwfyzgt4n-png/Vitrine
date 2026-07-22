import Foundation

struct CatalogHealthReport: Equatable, Sendable {
    var readableRecordCount: Int
    var unavailableCoverCount: Int
    var duplicateRecordCount: Int
    var damagedRecordCount: Int
    var warningCount: Int
    var backupCount: Int
    var latestBackupDate: Date?

    var isHealthy: Bool {
        duplicateRecordCount == 0 && damagedRecordCount == 0
    }
}

struct CoverInformationRebuildResult: Equatable, Sendable {
    var snapshot: CatalogSnapshot
    var refreshedRecordCount: Int
    var unmatchedRecordCount: Int
}
