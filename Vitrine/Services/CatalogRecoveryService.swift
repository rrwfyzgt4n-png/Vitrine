import Foundation

struct CatalogRecoveryBackupOption: Identifiable, Equatable, Sendable {
    var id: URL { backup.url }
    let backup: CatalogBackupService.Backup
    let parsedCatalog: CatalogParseResult

    var bookCount: Int { parsedCatalog.snapshot.items.count }
}

struct CatalogRecoveryCandidate: Sendable {
    let damagedCatalogURL: URL
    let catalogID: UUID?
    let preservedDamagedCopyURL: URL
    let backupOptions: [CatalogRecoveryBackupOption]
    let recoveredCatalog: CatalogParseResult?

    var backup: CatalogBackupService.Backup? { backupOptions.first?.backup }
    var parsedBackup: CatalogParseResult? { backupOptions.first?.parsedCatalog }
}

actor CatalogRecoveryService {
    private let backups = CatalogBackupService()
    private let markdownStore = CatalogMarkdownStore()

    func prepareRecovery(
        at catalogURL: URL,
        rememberedCatalogID: UUID? = nil
    ) async throws -> CatalogRecoveryCandidate {
        let data = try Data(contentsOf: catalogURL, options: [.mappedIfSafe])
        let source = String(data: data, encoding: .utf8)
        let catalogID = source.flatMap(catalogID(in:)) ?? rememberedCatalogID
        let preservedDamagedCopyURL = try await backups.preserveDamaged(data, catalogID: catalogID)
        let recoveredCatalog = source.flatMap {
            recoverReadableCatalog(from: $0, catalogURL: catalogURL, catalogID: catalogID)
        }
        var options: [CatalogRecoveryBackupOption] = []
        if let catalogID {
            for backup in try await backups.backups(catalogID: catalogID) {
                if let parsed = try? await markdownStore.read(from: backup.url),
                   parsed.snapshot.catalogID == catalogID,
                   !parsed.snapshot.items.isEmpty || parsed.diagnostics.allSatisfy({ $0.severity != .error }) {
                    options.append(CatalogRecoveryBackupOption(backup: backup, parsedCatalog: parsed))
                }
            }
        }
        return CatalogRecoveryCandidate(
            damagedCatalogURL: catalogURL,
            catalogID: catalogID,
            preservedDamagedCopyURL: preservedDamagedCopyURL,
            backupOptions: options,
            recoveredCatalog: recoveredCatalog
        )
    }

    nonisolated func diagnosticReport(for recovery: CatalogRecoveryCandidate) -> String {
        let diagnostics = recovery.recoveredCatalog?.diagnostics ?? []
        let warnings = diagnostics.filter { $0.severity == .warning }.count
        let errors = diagnostics.filter { $0.severity == .error }.count
        let diagnosticLines = diagnostics.map { diagnostic in
            let line = diagnostic.line.map { " line \($0)" } ?? ""
            return "- \(diagnostic.severity.rawValue): \(diagnostic.code.rawValue)\(line)"
        }
        let backupLines = recovery.backupOptions.map { option in
            "- \(CatalogDateFormatter.string(from: option.backup.date)): \(option.bookCount) readable records"
        }
        return ([
            "Vitrine Recovery Diagnostics",
            "Generated: \(CatalogDateFormatter.string(from: .now))",
            "Catalog identity available: \(recovery.catalogID == nil ? "no" : "yes")",
            "Readable records: \(recovery.recoveredCatalog?.snapshot.items.count ?? 0)",
            "Warnings: \(warnings)",
            "Errors: \(errors)",
            "Valid local backups: \(recovery.backupOptions.count)",
            "Damaged source preserved: yes",
            "",
            "Diagnostics"
        ] + (diagnosticLines.isEmpty ? ["- none"] : diagnosticLines) + [
            "",
            "Backups"
        ] + (backupLines.isEmpty ? ["- none"] : backupLines) + [
            "",
            "This report intentionally excludes file paths, book titles, notes, and catalog contents."
        ]).joined(separator: "\n")
    }

    private func catalogID(in source: String) -> UUID? {
        guard let expression = try? NSRegularExpression(pattern: #"(?m)^catalog-id:\s*([0-9A-Fa-f-]{36})\s*$"#),
              let match = expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let range = Range(match.range(at: 1), in: source) else { return nil }
        return UUID(uuidString: String(source[range]))
    }

    private func recoverReadableCatalog(
        from source: String,
        catalogURL: URL,
        catalogID: UUID?
    ) -> CatalogParseResult? {
        if let parsed = try? CatalogMarkdownParser().parse(source) {
            return parsed
        }
        let pattern = #"(?s)<!-- library-catalog:item:begin id=\"[0-9A-Fa-f-]{36}\" -->.*?<!-- library-catalog:item:end -->"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              !source.isEmpty else { return nil }
        let range = NSRange(source.startIndex..., in: source)
        let records = expression.matches(in: source, range: range).compactMap { match -> String? in
            guard let sourceRange = Range(match.range, in: source) else { return nil }
            return String(source[sourceRange])
        }
        guard !records.isEmpty else { return nil }
        let recoveryID = catalogID ?? UUID()
        let name = catalogURL.deletingPathExtension().lastPathComponent
        let stamp = CatalogDateFormatter.string(from: .now)
        let rebuilt = ([
            "---",
            "library-catalog-schema: 1",
            "catalog-id: \(recoveryID.uuidString)",
            "catalog-name: \(name)",
            "created-at: \(stamp)",
            "updated-at: \(stamp)",
            "record-count: \(records.count)",
            "generator: Vitrine Recovery",
            "---",
            "# \(name)",
            ""
        ] + records).joined(separator: "\n")
        guard var parsed = try? CatalogMarkdownParser().parse(rebuilt) else { return nil }
        parsed.diagnostics.insert(
            MarkdownDiagnostic(
                severity: .warning,
                code: .invalidFrontMatter,
                message: "The catalog header could not be read; readable record blocks were recovered independently."
            ),
            at: 0
        )
        return parsed
    }
}
