import Foundation

struct CatalogCoverInformationRebuilder: Sendable {
    func rebuild(
        catalog: CatalogSnapshot,
        scannedSources: [SourceFileMetadata]
    ) -> CoverInformationRebuildResult {
        let sourcesByPath = Dictionary(
            scannedSources.map { ($0.relativePath, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var result = catalog
        var refreshedCount = 0
        var unmatchedCount = 0

        for index in result.items.indices {
            let relativePath = result.items[index].source.relativePath
            guard let rebuiltSource = sourcesByPath[relativePath] else {
                unmatchedCount += 1
                continue
            }
            result.items[index].source = rebuiltSource
            result.items[index].availability = .available
            refreshedCount += 1
        }

        return CoverInformationRebuildResult(
            snapshot: result,
            refreshedRecordCount: refreshedCount,
            unmatchedRecordCount: unmatchedCount
        )
    }
}
