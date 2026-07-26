import Foundation

struct CatalogUITestFixture {
    var snapshot: CatalogSnapshot
    var diagnostics: [MarkdownDiagnostic]
    var sourceFolderURL: URL?
    var pendingMerge: PendingCatalogMerge?
    var pendingRecovery: CatalogRecoveryCandidate?
}

struct CatalogUITestFixtureBuilder {
    func build(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> CatalogUITestFixture? {
        guard environment["VITRINE_UI_TESTING"] == "1",
              let fixtureFlag = arguments.firstIndex(of: "-VitrineUITestFixture"),
              arguments.indices.contains(fixtureFlag + 1) else { return nil }

        let fixtureName = arguments[fixtureFlag + 1]
        let itemCount = fixtureName == "scale5000" ? 5_000 : 6
        let itemIDs = (1...itemCount).compactMap {
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))
        }
        let hasAvailableCovers = fixtureName == "available"
        let availability: ItemAvailability = hasAvailableCovers ? .available : .metadataOnly
        let items = itemIDs.enumerated().map { index, id in
            let itemNumber = index + 1
            let displayNumber = fixtureName == "scale5000"
                ? String(format: "%04d", itemNumber)
                : String(itemNumber)
            return CatalogItem(
                id: id,
                source: SourceFileMetadata(relativePath: "Book \(displayNumber).jpg"),
                bibliography: BibliographicMetadata(
                    title: "Book \(displayNumber)",
                    authors: ["Author \(displayNumber)"],
                    pageCount: 100 + index,
                    metadataSource: .manual,
                    metadataConfirmedByUser: true
                ),
                availability: availability
            )
        }

        var snapshot = CatalogSnapshot(name: "UI Test Library", items: items)
        if fixtureName == "unsupported" {
            snapshot.schemaVersion = CatalogSnapshot.supportedSchemaVersion + 1
            snapshot.isReadOnly = true
        }

        let diagnostics = fixtureName == "repairable"
            ? [MarkdownDiagnostic(
                severity: .error,
                code: .missingRequiredField,
                recordID: itemIDs.first,
                message: "A record could not be read."
            )]
            : []

        return CatalogUITestFixture(
            snapshot: snapshot,
            diagnostics: diagnostics,
            sourceFolderURL: hasAvailableCovers
                ? URL(fileURLWithPath: "/tmp/Vitrine-UI-Test-Covers", isDirectory: true)
                : nil,
            pendingMerge: conflictFixture(named: fixtureName, snapshot: snapshot, itemIDs: itemIDs),
            pendingRecovery: recoveryFixture(named: fixtureName, snapshot: snapshot)
        )
    }

    private func conflictFixture(
        named fixtureName: String,
        snapshot: CatalogSnapshot,
        itemIDs: [UUID]
    ) -> PendingCatalogMerge? {
        guard fixtureName == "conflict", let firstID = itemIDs.first else { return nil }
        var external = snapshot
        external.items[0].bibliography.title = "Other Title"
        return PendingCatalogMerge(
            merged: snapshot,
            external: external,
            conflicts: [CatalogMergeConflict(
                recordID: firstID,
                bookTitle: "Book 1",
                field: .title,
                localValue: "Book 1",
                externalValue: "Other Title"
            )]
        )
    }

    private func recoveryFixture(
        named fixtureName: String,
        snapshot: CatalogSnapshot
    ) -> CatalogRecoveryCandidate? {
        guard fixtureName == "repair" else { return nil }
        let damagedURL = URL(fileURLWithPath: "/tmp/Vitrine-UI-Test-Damaged.md")
        let backup = CatalogBackupService.Backup(
            url: URL(fileURLWithPath: "/tmp/Vitrine-UI-Test-Backup.md"),
            date: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let parseResult = CatalogParseResult(snapshot: snapshot, diagnostics: [])
        return CatalogRecoveryCandidate(
            damagedCatalogURL: damagedURL,
            catalogID: snapshot.catalogID,
            preservedDamagedCopyURL: damagedURL,
            backupOptions: [CatalogRecoveryBackupOption(backup: backup, parsedCatalog: parseResult)],
            recoveredCatalog: parseResult
        )
    }
}
