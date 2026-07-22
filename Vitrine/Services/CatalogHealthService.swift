import Foundation

struct CatalogHealthService: Sendable {
    func report(
        catalog: CatalogSnapshot,
        diagnostics: [MarkdownDiagnostic],
        backups: [CatalogBackupService.Backup]
    ) -> CatalogHealthReport {
        let duplicatePaths = Dictionary(grouping: catalog.items, by: { $0.source.relativePath })
            .values
            .reduce(0) { count, records in count + max(0, records.count - 1) }
        let duplicateDiagnostics = diagnostics.filter { $0.code == .duplicateRecordID }.count
        let damagedRecordIDs = Set(
            diagnostics
                .filter { $0.severity == .error && $0.code != .duplicateRecordID }
                .compactMap(\.recordID)
        )
        let catalogLevelErrors = diagnostics.filter {
            $0.severity == .error && $0.code != .duplicateRecordID && $0.recordID == nil
        }.count

        return CatalogHealthReport(
            readableRecordCount: catalog.items.count,
            unavailableCoverCount: catalog.items.filter { $0.availability != .available }.count,
            duplicateRecordCount: duplicatePaths + duplicateDiagnostics,
            damagedRecordCount: damagedRecordIDs.count + catalogLevelErrors,
            warningCount: diagnostics.filter { $0.severity == .warning }.count,
            backupCount: backups.count,
            latestBackupDate: backups.first?.date
        )
    }
}
