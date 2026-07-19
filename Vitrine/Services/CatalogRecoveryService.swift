import Foundation

struct CatalogRecoveryCandidate: Sendable {
    let damagedCatalogURL: URL
    let catalogID: UUID
    let backup: CatalogBackupService.Backup
    let parsedBackup: CatalogParseResult
}

actor CatalogRecoveryService {
    private let backups = CatalogBackupService()
    private let markdownStore = CatalogMarkdownStore()

    func prepareRecovery(at catalogURL: URL) async throws -> CatalogRecoveryCandidate {
        let data = try Data(contentsOf: catalogURL, options: [.mappedIfSafe])
        guard let source = String(data: data, encoding: .utf8),
              let catalogID = catalogID(in: source) else {
            throw CatalogError.catalogMalformed
        }

        try await backups.preserveCurrentCatalog(at: catalogURL, catalogID: catalogID)
        for backup in try await backups.backups(catalogID: catalogID) {
            if let parsed = try? await markdownStore.read(from: backup.url),
               parsed.snapshot.catalogID == catalogID,
               !parsed.snapshot.items.isEmpty || parsed.diagnostics.allSatisfy({ $0.severity != .error }) {
                return CatalogRecoveryCandidate(
                    damagedCatalogURL: catalogURL,
                    catalogID: catalogID,
                    backup: backup,
                    parsedBackup: parsed
                )
            }
        }
        throw CatalogError.catalogMalformed
    }

    private func catalogID(in source: String) -> UUID? {
        guard let expression = try? NSRegularExpression(pattern: #"(?m)^catalog-id:\s*([0-9A-Fa-f-]{36})\s*$"#),
              let match = expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let range = Range(match.range(at: 1), in: source) else { return nil }
        return UUID(uuidString: String(source[range]))
    }
}
