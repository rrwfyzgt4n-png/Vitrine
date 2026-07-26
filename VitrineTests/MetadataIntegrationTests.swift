import XCTest
@testable import Vitrine

final class MetadataIntegrationTests: XCTestCase {
    @MainActor
    func testRepeatedReviewedFilenameSuggestionsSaveImmediatelyAndSurviveReopen() async throws {
        let catalogID = UUID()
        let first = CatalogItem(source: SourceFileMetadata(relativePath: "First.jpg"))
        let second = CatalogItem(source: SourceFileMetadata(relativePath: "Second.jpg"))
        let snapshot = CatalogSnapshot(catalogID: catalogID, name: "Library", items: [first, second])
        let url = FileManager.default.temporaryDirectory.appending(path: "\(catalogID.uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .seconds(2))
        try await coordinator.save(snapshot, to: url)
        let store = CatalogStore(saveCoordinator: coordinator, catalogURL: url, undoManagerProvider: { nil })
        store.catalog = snapshot

        let started = CFAbsoluteTimeGetCurrent()
        let firstSaved = await store.applyFilenameSuggestion(
            filenameSuggestion(title: "First Parsed Title"),
            to: first.id
        )
        let secondSaved = await store.applyFilenameSuggestion(
            filenameSuggestion(
                title: "Second Parsed Title",
                publisher: "Second Publisher",
                pageCount: 277
            ),
            to: second.id
        )
        let elapsed = CFAbsoluteTimeGetCurrent() - started
        let reopened = try await CatalogMarkdownStore().read(from: url).snapshot
        let reopenedByID = Dictionary(uniqueKeysWithValues: reopened.items.map { ($0.id, $0) })

        XCTAssertTrue(firstSaved)
        XCTAssertTrue(secondSaved)
        XCTAssertLessThan(elapsed, 1.5, "A reviewed Save must bypass the autosave debounce.")
        XCTAssertEqual(reopenedByID[first.id]?.bibliography.title, "First Parsed Title")
        XCTAssertEqual(reopenedByID[second.id]?.bibliography.title, "Second Parsed Title")
        XCTAssertEqual(reopenedByID[second.id]?.bibliography.publisher, "Second Publisher")
        XCTAssertEqual(reopenedByID[second.id]?.bibliography.pageCount, 277)
        XCTAssertEqual(store.catalog?.items.map(\.id), reopened.items.map(\.id))
        XCTAssertEqual(
            store.catalog?.items.map(\.bibliography),
            reopened.items.map(\.bibliography)
        )
        XCTAssertEqual(store.catalog?.catalogID, reopened.catalogID)

        if let folder = try await coordinator.backups(catalogID: catalogID).first?.url.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    @MainActor
    func testReviewedFilenameSuggestionRegistersUndoOnlyAfterReviewSheetDismisses() async throws {
        let catalogID = UUID()
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Book.jpg"))
        let snapshot = CatalogSnapshot(catalogID: catalogID, name: "Library", items: [item])
        let url = FileManager.default.temporaryDirectory.appending(path: "\(catalogID.uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let undoManager = UndoManager()
        let coordinator = CatalogSaveCoordinator(editDebounce: .milliseconds(80))
        try await coordinator.save(snapshot, to: url)
        let store = CatalogStore(
            saveCoordinator: coordinator,
            catalogURL: url,
            undoManagerProvider: { undoManager }
        )
        store.catalog = snapshot
        store.selection = item.id
        store.suggestDetailsFromFilename()

        let didSave = await store.applyFilenameSuggestion(
            filenameSuggestion(title: "Persisted Parsed Title"),
            to: item.id
        )

        XCTAssertTrue(didSave)
        XCTAssertFalse(
            undoManager.canUndo,
            "The review sheet must not own the catalog undo registration."
        )

        undoManager.undo()
        try await Task.sleep(for: .milliseconds(150))

        var reopened = try await CatalogMarkdownStore().read(from: url).snapshot
        XCTAssertEqual(reopened.items.first?.bibliography.title, "Persisted Parsed Title")

        store.finishFilenameSuggestionReviewPresentation()
        XCTAssertFalse(
            undoManager.canUndo,
            "Sheet cleanup must finish before the catalog undo is registered."
        )

        undoManager.undo()
        await Task.yield()
        XCTAssertTrue(undoManager.canUndo)

        try await Task.sleep(for: .milliseconds(150))
        reopened = try await CatalogMarkdownStore().read(from: url).snapshot
        XCTAssertEqual(reopened.items.first?.bibliography.title, "Persisted Parsed Title")

        if let folder = try await coordinator.backups(catalogID: catalogID).first?.url.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    func testReviewedFilenameSuggestionAdapterMapsEveryParserField() {
        let original = CatalogItem(
            source: SourceFileMetadata(relativePath: "Book.jpg"),
            bibliography: BibliographicMetadata(metadataSource: .manual)
        )
        let contributor = BibliographicContributor(name: "Editor Example", roles: [.editor, .annotator])
        let suggestion = FilenameMetadataSuggestion(
            title: suggested("The Complete Title"),
            subtitle: suggested("A Subtitle"),
            authors: suggested(["Author One", "Author Two"]),
            translators: suggested(["Translator"]),
            contributors: suggested([contributor]),
            publisher: suggested("Integration Press"),
            collectionName: suggested("Collection Name"),
            collectionNumber: suggested("42"),
            publicationPlace: suggested("Montréal"),
            publicationDate: suggested("1988"),
            originalPublicationDate: suggested("1963"),
            editionDescription: suggested("Second edition"),
            volumeDescription: suggested("Volume 7"),
            languageCodes: suggested(["fr", "en"]),
            originalLanguageCode: suggested("it"),
            pageCount: suggested(277),
            paginationStatus: suggested(.nonPaginated),
            physicalAttributes: suggested([.illustrated, .foldoutMaps]),
            descriptiveNotes: suggested("Includes a map.")
        )

        let result = FilenameMetadataSuggestionAdapter().applying(suggestion, to: original)
        let metadata = result.bibliography

        XCTAssertEqual(metadata.title, "The Complete Title")
        XCTAssertEqual(metadata.subtitle, "A Subtitle")
        XCTAssertEqual(metadata.authors, ["Author One", "Author Two"])
        XCTAssertEqual(metadata.translators, ["Translator"])
        XCTAssertEqual(metadata.contributors, [contributor])
        XCTAssertEqual(metadata.publisher, "Integration Press")
        XCTAssertEqual(metadata.collectionName, "Collection Name")
        XCTAssertEqual(metadata.collectionNumber, "42")
        XCTAssertEqual(metadata.publicationPlace, "Montréal")
        XCTAssertEqual(metadata.publicationDate, "1988")
        XCTAssertEqual(metadata.originalPublicationDate, "1963")
        XCTAssertEqual(metadata.editionDescription, "Second edition")
        XCTAssertEqual(metadata.volumeDescription, "Volume 7")
        XCTAssertEqual(metadata.languageCode, "fr")
        XCTAssertEqual(metadata.additionalLanguageCodes, ["en"])
        XCTAssertEqual(metadata.originalLanguageCode, "it")
        XCTAssertEqual(metadata.pageCount, 277)
        XCTAssertEqual(metadata.paginationStatus, .nonPaginated)
        XCTAssertEqual(metadata.physicalAttributes, [.illustrated, .foldoutMaps])
        XCTAssertEqual(metadata.description, "Includes a map.")
        XCTAssertEqual(metadata.metadataSource, .mixed)
        XCTAssertTrue(metadata.metadataConfirmedByUser)
    }

    func testPostParserCatalogRoundTripsEveryBibliographicField() throws {
        let date = try XCTUnwrap(CatalogDateFormatter.date(from: "2026-07-21T12:00:00Z"))
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Covers/Complete.jpg"),
            bibliography: completeMetadata(suffix: "Persisted", retrievedAt: date),
            personalNotes: "A private note",
            dateAdded: date,
            dateModified: date
        )
        let snapshot = CatalogSnapshot(name: "Compatibility", createdAt: date, updatedAt: date, items: [item])

        let markdown = try CatalogMarkdownWriter().render(snapshot)
        let reopened = try CatalogMarkdownParser().parse(markdown).snapshot

        XCTAssertEqual(reopened.items.first?.bibliography, item.bibliography)
        XCTAssertEqual(reopened.items.first?.personalNotes, item.personalNotes)
    }

    func testPreParserCatalogRemainsCompatibleAfterRewrite() throws {
        let source = """
        ---
        library-catalog-schema: 1
        catalog-id: 14839B3C-218A-440A-B4F4-6454168AFC57
        catalog-name: Legacy Library
        created-at: 2025-01-02T03:04:05Z
        updated-at: 2025-01-02T03:04:05Z
        record-count: 1
        legacy-front-field: retained
        ---
        # Legacy Library

        <!-- library-catalog:item:begin id="29FC364D-BD3C-4E78-9B77-92781A43AF19" -->
        ## Legacy Book
        - source-file: `Legacy Book.jpg`
        - source-title: `Legacy Book`
        - file-size: `12345`
        - availability: `available`
        - date-added: `2025-01-02T03:04:05Z`
        - record-modified: `2025-01-02T03:04:05Z`
        - legacy-record-field: `retained`
        <!-- library-catalog:item:end -->
        """

        let first = try CatalogMarkdownParser().parse(source).snapshot
        let rewritten = try CatalogMarkdownWriter().render(first)
        let second = try CatalogMarkdownParser().parse(rewritten).snapshot

        XCTAssertEqual(second.items.count, 1)
        XCTAssertEqual(second.items[0].displayTitle, "Legacy Book")
        XCTAssertEqual(second.items[0].bibliography, BibliographicMetadata())
        XCTAssertEqual(second.unknownFrontMatter["legacy-front-field"], "retained")
        XCTAssertEqual(second.items[0].unrecognizedLines, ["- legacy-record-field: `retained`"])
    }

    func testExternalChangesToEveryBibliographicFieldMergeIntoAnUnchangedCatalog() async {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let baseItem = CatalogItem(
            id: id,
            source: SourceFileMetadata(relativePath: "Book.jpg"),
            bibliography: BibliographicMetadata(),
            dateAdded: date,
            dateModified: date
        )
        let base = CatalogSnapshot(name: "Library", createdAt: date, updatedAt: date, items: [baseItem])
        let local = base
        var external = base
        external.items[0].bibliography = completeMetadata(suffix: "External", retrievedAt: date)

        let pending = await CatalogMergeService().merge(base: base, local: local, external: external)

        XCTAssertTrue(pending.conflicts.isEmpty)
        XCTAssertEqual(pending.merged.items[0].bibliography, external.items[0].bibliography)
    }

    @MainActor
    func testParserIntegratedFieldsParticipateInSearch() {
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Book.jpg"),
            bibliography: completeMetadata(suffix: "SearchToken", retrievedAt: .now)
        )
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Library", items: [item])
        let queries = [
            "Title SearchToken", "Subtitle SearchToken", "Author SearchToken",
            "Translator SearchToken", "Contributor SearchToken", "Publisher SearchToken",
            "Collection SearchToken", "Montréal SearchToken", "Original SearchToken",
            "Edition SearchToken", "Volume SearchToken", "Subject SearchToken",
            "Description SearchToken", "foldout-maps",
        ]

        for query in queries {
            store.searchText = query
            XCTAssertEqual(store.visibleItems.map(\.id), [item.id], "Missing search integration for: \(query)")
        }
    }

    private func suggested<Value>(_ value: Value) -> SuggestedValue<Value> {
        SuggestedValue(value: value, confidence: .high, evidence: "fixture")
    }

    private func filenameSuggestion(
        title: String,
        publisher: String? = nil,
        pageCount: Int? = nil
    ) -> FilenameMetadataSuggestion {
        FilenameMetadataSuggestion(
            title: suggested(title),
            subtitle: nil,
            authors: nil,
            translators: nil,
            contributors: nil,
            publisher: publisher.map(suggested),
            collectionName: nil,
            collectionNumber: nil,
            publicationPlace: nil,
            publicationDate: nil,
            originalPublicationDate: nil,
            editionDescription: nil,
            volumeDescription: nil,
            languageCodes: nil,
            originalLanguageCode: nil,
            pageCount: pageCount.map(suggested),
            paginationStatus: nil,
            physicalAttributes: nil,
            descriptiveNotes: nil
        )
    }

    private func completeMetadata(suffix: String, retrievedAt: Date) -> BibliographicMetadata {
        BibliographicMetadata(
            isbn10: "0123456789",
            isbn13: "9780123456786",
            title: "Title \(suffix)",
            subtitle: "Subtitle \(suffix)",
            authors: ["Author \(suffix)"],
            translators: ["Translator \(suffix)"],
            contributors: [.init(name: "Contributor \(suffix)", roles: [.editor, .illustrator])],
            publisher: "Publisher \(suffix)",
            collectionName: "Collection \(suffix)",
            collectionNumber: "Number \(suffix)",
            publicationPlace: "Montréal \(suffix)",
            publicationDate: "Published \(suffix)",
            originalPublicationDate: "Original \(suffix)",
            editionDescription: "Edition \(suffix)",
            volumeDescription: "Volume \(suffix)",
            languageCode: "fr-\(suffix)",
            additionalLanguageCodes: ["en-\(suffix)"],
            originalLanguageCode: "it-\(suffix)",
            pageCount: 321,
            paginationStatus: .nonPaginated,
            physicalAttributes: [.illustrated, .foldoutMaps],
            subjects: ["Subject \(suffix)"],
            description: "Description \(suffix)",
            openLibraryEditionID: "EditionID-\(suffix)",
            openLibraryWorkID: "WorkID-\(suffix)",
            metadataSource: .mixed,
            metadataRetrievedAt: retrievedAt,
            metadataConfirmedByUser: true
        )
    }
}
