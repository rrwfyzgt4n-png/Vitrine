import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class CatalogStore {
    private let scanner = CatalogScanner()
    private let reconciler = CatalogReconciler()
    private let markdownStore = CatalogMarkdownStore()
    private let saveCoordinator = CatalogSaveCoordinator()
    private let bookmarkStore = SecurityScopedBookmarkStore.shared
    private let folderValidator = SourceFolderValidator()
    private let filenameParser = FilenameMetadataParser()
    private let openLibrary = OpenLibraryService()
    private let mergeService = CatalogMergeService()
    private let recoveryService = CatalogRecoveryService()
    private let accessController = SecurityScopedAccessController()

    var catalog: CatalogSnapshot?
    private(set) var catalogURL: URL?
    private(set) var sourceFolderURL: URL?
    var selection: CatalogItem.ID?
    var searchText = ""
    var sortOption: CatalogSortOption = CatalogSortOption(
        rawValue: UserDefaults.standard.string(forKey: "sortOption") ?? ""
    ) ?? .titleAscending {
        didSet { UserDefaults.standard.set(sortOption.rawValue, forKey: "sortOption") }
    }
    var filter: CatalogFilter = CatalogFilter(
        rawValue: UserDefaults.standard.string(forKey: "catalogFilter") ?? ""
    ) ?? .all {
        didSet { UserDefaults.standard.set(filter.rawValue, forKey: "catalogFilter") }
    }
    var isInspectorPresented = UserDefaults.standard.bool(forKey: "inspectorPresented") {
        didSet { UserDefaults.standard.set(isInspectorPresented, forKey: "inspectorPresented") }
    }
    var scanState: ScanState = .idle
    var saveState: SaveState = .idle
    var presentedError: CatalogError?
    var isPerformingCatalogOperation = false
    var operationMessage: String?
    var statusMessage: String? {
        didSet {
            statusClearTask?.cancel()
            guard let scheduledMessage = statusMessage else { return }
            statusClearTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, self?.statusMessage == scheduledMessage else { return }
                self?.statusMessage = nil
            }
        }
    }
    var scanWarnings: [CatalogScanWarning] = []
    var filenameSuggestion: FilenameMetadataSuggestion?
    var isFilenameReviewPresented = false
    var isMetadataEditorPresented = false
    var isLookupPresented = false
    var lookupCandidates: [MetadataCandidate] = []
    var isLookingUp = false
    var lookupMessage: String?
    var lookupTitle = ""
    var lookupAuthor = ""
    var lookupISBN = ""
    var pendingCatalogMerge: PendingCatalogMerge?
    var isConflictReviewPresented = false
    var ambiguousCandidates: [UUID: [FileCandidate]] = [:]
    var isAmbiguousReviewPresented = false
    var pendingMismatchedFolderURL: URL?
    var isWrongFolderConfirmationPresented = false
    var pendingRecovery: CatalogRecoveryCandidate?
    var isRecoveryPresented = false
    var focusSearchRequest = 0
    private(set) var canCancelOperation = false

    private var hasStarted = false
    @ObservationIgnored private var filePresenter: CatalogFilePresenter?
    @ObservationIgnored private var filePresenterTask: Task<Void, Never>?
    @ObservationIgnored private var statusClearTask: Task<Void, Never>?
    @ObservationIgnored private var allowSourceFolderMismatchOnce = false
    @ObservationIgnored private var activeScanTask: Task<CatalogScanResult, any Error>?
    @ObservationIgnored private var activeReconciliationTask: Task<CatalogReconciliationDiff, any Error>?

    var canRefreshCovers: Bool {
        catalog != nil && catalog?.isReadOnly == false && sourceFolderURL != nil && !isPerformingCatalogOperation
    }

    var isBrowsingWithoutCovers: Bool {
        catalog != nil && sourceFolderURL == nil
    }

    var visibleItems: [CatalogItem] {
        guard let catalog else { return [] }
        let query = SearchNormalizer.normalize(searchText)
        let filtered = catalog.items.filter { item in
            matchesFilter(item) && (query.isEmpty || searchableText(for: item).contains(query))
        }
        return filtered.sorted(by: areInIncreasingOrder)
    }

    var selectedItem: CatalogItem? {
        guard let selection else { return nil }
        return catalog?.items.first { $0.id == selection }
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        if ProcessInfo.processInfo.arguments.contains("-VitrineSkipRestoreLastCatalog") { return }
        await restoreLastCatalog()
    }

    func applicationBecameActive() async {
        guard catalog != nil else { return }
        if sourceFolderURL == nil { await reconnectMountedVolume() }
        if canRefreshCovers { await refreshCovers(showStatus: false) }
    }

    func mountedVolumesChanged() async {
        guard sourceFolderURL == nil else { return }
        await reconnectMountedVolume()
    }

    func showInspector() {
        isInspectorPresented.toggle()
    }

    func focusSearch() {
        focusSearchRequest += 1
    }

    func cancelCurrentOperation() {
        activeScanTask?.cancel()
        activeReconciliationTask?.cancel()
    }

    func saveNow() async {
        guard let catalog, let catalogURL, !catalog.isReadOnly else { return }
        do {
            saveState = .saving
            try await saveCoordinator.save(catalog, to: catalogURL)
            saveState = .saved(.now)
            statusMessage = L10n.text("Catalog saved")
        } catch {
            presentedError = .coordinatedWriteFailed
        }
    }

    func exportCatalogCopy() async {
        guard let catalog,
              let destination = CatalogPanelService.chooseCatalogCopyDestination(catalogName: catalog.name) else { return }
        do {
            var copy = catalog
            copy.isReadOnly = false
            try await saveCoordinator.save(copy, to: destination)
            statusMessage = L10n.text("Catalog copy exported")
        } catch {
            presentedError = .coordinatedWriteFailed
        }
    }

    func showLocalBackups() async {
        guard let catalog else { return }
        do {
            guard let latest = try await saveCoordinator.backups(catalogID: catalog.catalogID).first else {
                statusMessage = L10n.text("No catalog backups are available.")
                return
            }
            NSWorkspace.shared.activateFileViewerSelecting([latest.url])
        } catch {
            presentedError = .catalogUnavailable
        }
    }

    func openCatalogInTextEditor() {
        guard let catalogURL else { return }
        NSWorkspace.shared.open(catalogURL)
    }

    func copySelectedTitle() {
        guard let title = selectedItem?.displayTitle else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(title, forType: .string)
    }

    func copySelectedISBN() {
        guard let item = selectedItem,
              let isbn = item.bibliography.isbn13 ?? item.bibliography.isbn10 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(isbn, forType: .string)
    }

    func keepSelectedWithoutCover() async {
        guard var item = selectedItem else { return }
        item.availability = .metadataOnly
        await saveEditedItem(item, actionName: "Keep Without Cover")
    }

    func createCatalog() async {
        guard !isPerformingCatalogOperation,
              let folderURL = CatalogPanelService.chooseCoverFolder(),
              let destinationURL = CatalogPanelService.chooseCatalogDestination(for: folderURL) else { return }

        await performCatalogOperation(message: L10n.text("Adding covers…"), failure: .coordinatedWriteFailed) {
            let scan = try await scan(folderURL: folderURL)
            let now = Date.now
            var snapshot = CatalogSnapshot(
                name: folderURL.lastPathComponent.isEmpty ? "My Library" : folderURL.lastPathComponent,
                createdAt: now,
                updatedAt: now,
                sourceFolderName: folderURL.lastPathComponent,
                items: scan.sources.map { CatalogItem(source: $0, dateAdded: now, dateModified: now) }
            )
            snapshot.sourceFolderSignature = folderValidator.signature(
                folderName: folderURL.lastPathComponent,
                sources: scan.sources,
                catalogID: snapshot.catalogID
            )
            saveState = .saving
            try await saveCoordinator.save(snapshot, to: destinationURL)
            accessController.replace(catalogURL: destinationURL, coverFolderURL: folderURL)
            try await persistAccess(catalogURL: destinationURL, coverFolderURL: folderURL, snapshot: snapshot)
            catalog = snapshot
            catalogURL = destinationURL
            sourceFolderURL = folderURL
            startPresentingCatalog(at: destinationURL)
            selection = snapshot.items.first?.id
            scanWarnings = scan.warnings
            saveState = .saved(.now)
            scanState = .completed(warnings: scan.warnings.count)
        }
    }

    func openCatalog() async {
        guard !isPerformingCatalogOperation,
              let selectedURL = CatalogPanelService.chooseCatalogToOpen() else { return }
        await openCatalog(at: selectedURL, rememberedFolderURL: nil, refreshAfterOpening: true)
    }

    func restorePendingRecovery() async {
        guard let recovery = pendingRecovery, !isPerformingCatalogOperation else { return }
        let rememberedFolderURL = sourceFolderURL
        isRecoveryPresented = false
        await performCatalogOperation(message: L10n.text("Restoring catalog backup…"), failure: .coordinatedWriteFailed) {
            try await saveCoordinator.restore(
                recovery.backup,
                to: recovery.damagedCatalogURL,
                catalogID: recovery.catalogID
            )
            pendingRecovery = nil
        }
        guard pendingRecovery == nil else { return }
        statusMessage = L10n.text("The damaged catalog was preserved and the selected backup was restored.")
        await openCatalog(
            at: recovery.damagedCatalogURL,
            rememberedFolderURL: rememberedFolderURL,
            refreshAfterOpening: true
        )
    }

    func revealPendingRecoveryBackup() {
        guard let recovery = pendingRecovery else { return }
        NSWorkspace.shared.activateFileViewerSelecting([recovery.backup.url])
    }

    func cancelPendingRecovery() {
        pendingRecovery = nil
        isRecoveryPresented = false
    }

    func locateCoverFolder() async {
        guard let currentCatalog = catalog,
              !isPerformingCatalogOperation,
              let folderURL = CatalogPanelService.chooseCoverFolder() else { return }

        await performCatalogOperation(message: L10n.text("Checking cover folder…"), failure: .folderEnumerationFailed) {
            let scan = try await scan(folderURL: folderURL)
            guard folderValidator.looksLikeCatalogFolder(
                catalog: currentCatalog,
                sources: scan.sources,
                folderName: folderURL.lastPathComponent
            ) else {
                pendingMismatchedFolderURL = folderURL
                isWrongFolderConfirmationPresented = true
                return
            }
            sourceFolderURL = folderURL
            accessController.replaceCoverFolder(with: folderURL)
            try await persistAccess(catalogURL: try requiredCatalogURL(), coverFolderURL: folderURL, snapshot: currentCatalog)
        }
        if sourceFolderURL == folderURL { await refreshCovers() }
    }

    func usePendingMismatchedFolder() async {
        guard let folderURL = pendingMismatchedFolderURL, let catalog else { return }
        sourceFolderURL = folderURL
        accessController.replaceCoverFolder(with: folderURL)
        allowSourceFolderMismatchOnce = true
        pendingMismatchedFolderURL = nil
        isWrongFolderConfirmationPresented = false
        try? await persistAccess(catalogURL: try requiredCatalogURL(), coverFolderURL: folderURL, snapshot: catalog)
        await refreshCovers()
    }

    func refreshCovers(showStatus: Bool = true) async {
        guard let currentCatalog = catalog,
              !currentCatalog.isReadOnly,
              let folderURL = sourceFolderURL,
              let catalogURL,
              !isPerformingCatalogOperation else { return }

        await performCatalogOperation(
            message: showStatus ? L10n.text("Refreshing covers…") : nil,
            failure: .folderEnumerationFailed
        ) {
            scanState = .refreshing(completed: 0, total: nil)
            let diff = try await reconcile(catalog: currentCatalog, folderURL: folderURL)
            guard diff.baseCatalogID == currentCatalog.catalogID else { throw CatalogError.sourceFolderMismatch }
            guard diff.sourceFolderValidated || allowSourceFolderMismatchOnce else { throw CatalogError.sourceFolderMismatch }
            allowSourceFolderMismatchOnce = false
            var refreshed = apply(diff: diff, to: currentCatalog)
            refreshed.updatedAt = .now
            refreshed.sourceFolderName = folderURL.lastPathComponent
            refreshed.sourceFolderSignature = folderValidator.signature(
                folderName: folderURL.lastPathComponent,
                sources: diff.scannedSources,
                catalogID: refreshed.catalogID
            )
            saveState = .saving
            try await saveCoordinator.save(refreshed, to: catalogURL, reason: .refresh)
            await ThumbnailService.shared.removeAll()
            catalog = refreshed
            if let selection, !refreshed.items.contains(where: { $0.id == selection }) {
                self.selection = refreshed.items.first?.id
            }
            scanWarnings = diff.warnings.map { CatalogScanWarning(relativePath: "", message: $0) }
            saveState = .saved(.now)
            scanState = .completed(warnings: diff.warnings.count)
            statusMessage = diff.warnings.first
            do {
                try await persistAccess(catalogURL: catalogURL, coverFolderURL: folderURL, snapshot: refreshed)
            } catch {
                presentedError = .accessPersistenceFailed
            }
        }
    }

    func saveEditedItem(_ editedItem: CatalogItem, actionName: String = "Edit Book Details") async {
        guard var snapshot = catalog, !snapshot.isReadOnly, let catalogURL,
              let index = snapshot.items.firstIndex(where: { $0.id == editedItem.id }) else { return }
        let previous = snapshot.items[index]
        var edited = editedItem
        if edited.bibliography.metadataSource == .manual,
           let existing = previous.bibliography.metadataSource,
           existing != .manual {
            edited.bibliography.metadataSource = .mixed
        }
        edited.dateModified = .now
        snapshot.items[index] = edited
        snapshot.updatedAt = .now
        catalog = snapshot
        registerUndo(previous: previous, actionName: actionName)
        do {
            saveState = .saving
            try await saveCoordinator.save(snapshot, to: catalogURL, reason: .metadataEdit)
            saveState = .saved(.now)
        } catch {
            presentedError = .coordinatedWriteFailed
            saveState = .failed(error.localizedDescription)
        }
    }

    func removeSelectedBook() async {
        guard var snapshot = catalog, !snapshot.isReadOnly, let selected = selection, let catalogURL else { return }
        guard let index = snapshot.items.firstIndex(where: { $0.id == selected }) else { return }
        let removed = snapshot.items.remove(at: index)
        snapshot.updatedAt = .now
        do {
            try await saveCoordinator.save(snapshot, to: catalogURL)
            catalog = snapshot
            selection = snapshot.items.first?.id
            registerRemovalUndo(item: removed, index: index)
        } catch { presentedError = .coordinatedWriteFailed }
    }

    func restoreLatestBackup() async {
        guard let current = catalog, let catalogURL, !isPerformingCatalogOperation else { return }
        await performCatalogOperation(message: L10n.text("Restoring latest backup…"), failure: .coordinatedWriteFailed) {
            guard let backup = try await saveCoordinator.backups(catalogID: current.catalogID).first else {
                statusMessage = L10n.text("No catalog backups are available.")
                return
            }
            try await saveCoordinator.restore(backup, to: catalogURL, catalogID: current.catalogID)
            let restored = try await markdownStore.read(from: catalogURL).snapshot
            catalog = restored
            selection = restored.items.first?.id
            try await saveCoordinator.establishBaseline(restored, at: catalogURL)
            statusMessage = L10n.text("Latest catalog backup restored")
        }
    }

    func resolveCatalogConflicts(useExternal conflictIDs: Set<UUID>) async {
        guard let pendingCatalogMerge, let catalogURL else { return }
        let resolved = await mergeService.resolving(pendingCatalogMerge, useExternal: conflictIDs)
        do {
            saveState = .saving
            try await saveCoordinator.save(resolved, to: catalogURL, reason: .conflictResolution)
            catalog = resolved
            self.pendingCatalogMerge = nil
            isConflictReviewPresented = false
            saveState = .saved(.now)
            statusMessage = L10n.text("Catalog conflicts resolved")
        } catch {
            presentedError = .coordinatedWriteFailed
            saveState = .failed(error.localizedDescription)
        }
    }

    func associateSelectedCover(relativePath: String) async {
        guard var item = selectedItem, let folderURL = sourceFolderURL else { return }
        do {
            let scan = try await scan(folderURL: folderURL)
            guard let source = scan.sources.first(where: { $0.relativePath == relativePath }) else {
                throw CatalogError.sourceFolderUnavailable
            }
            item.source = source
            item.availability = .available
            await saveEditedItem(item, actionName: "Associate Cover")
            ambiguousCandidates[item.id] = nil
            isAmbiguousReviewPresented = false
        } catch let error as CatalogError {
            presentedError = error
        } catch {
            presentedError = .folderEnumerationFailed
        }
    }

    func chooseReplacementCover() async {
        guard let root = sourceFolderURL,
              let selected = CatalogPanelService.chooseCoverFile(in: root) else { return }
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let canonicalFile = selected.resolvingSymlinksInPath().standardizedFileURL
        let rootComponents = canonicalRoot.pathComponents
        guard canonicalFile.pathComponents.count > rootComponents.count,
              Array(canonicalFile.pathComponents.prefix(rootComponents.count)) == rootComponents else {
            presentedError = .sourceFolderMismatch
            return
        }
        let relativePath = canonicalFile.pathComponents.dropFirst(rootComponents.count).joined(separator: "/")
        await associateSelectedCover(relativePath: relativePath)
    }

    func suggestDetailsFromFilename() {
        guard let selectedItem else { return }
        filenameSuggestion = filenameParser.suggestions(from: selectedItem.source.sourceTitle)
        isFilenameReviewPresented = true
    }

    func applyFilenameSuggestion(_ suggestion: FilenameMetadataSuggestion) async {
        guard var item = selectedItem else { return }
        if let value = suggestion.title?.value { item.bibliography.title = value }
        if let value = suggestion.subtitle?.value { item.bibliography.subtitle = value }
        if let value = suggestion.authors?.value { item.bibliography.authors = value }
        if let value = suggestion.translators?.value { item.bibliography.translators = value }
        if let value = suggestion.contributors?.value { item.bibliography.contributors = value }
        if let value = suggestion.publisher?.value { item.bibliography.publisher = value }
        if let value = suggestion.collectionName?.value { item.bibliography.collectionName = value }
        if let value = suggestion.collectionNumber?.value { item.bibliography.collectionNumber = value }
        if let value = suggestion.publicationPlace?.value { item.bibliography.publicationPlace = value }
        if let value = suggestion.publicationDate?.value { item.bibliography.publicationDate = value }
        if let value = suggestion.originalPublicationDate?.value { item.bibliography.originalPublicationDate = value }
        if let value = suggestion.editionDescription?.value { item.bibliography.editionDescription = value }
        if let value = suggestion.volumeDescription?.value { item.bibliography.volumeDescription = value }
        if let value = suggestion.languageCodes?.value, let primary = value.first {
            item.bibliography.languageCode = primary
            item.bibliography.additionalLanguageCodes = Array(value.dropFirst())
        }
        if let value = suggestion.originalLanguageCode?.value { item.bibliography.originalLanguageCode = value }
        if let value = suggestion.pageCount?.value { item.bibliography.pageCount = value }
        if let value = suggestion.paginationStatus?.value { item.bibliography.paginationStatus = value }
        if let value = suggestion.physicalAttributes?.value { item.bibliography.physicalAttributes = value }
        if let value = suggestion.descriptiveNotes?.value { item.bibliography.description = value }
        item.bibliography.metadataSource = provenance(adding: .filename, to: item.bibliography.metadataSource)
        item.bibliography.metadataConfirmedByUser = true
        await saveEditedItem(item, actionName: "Accept Filename Suggestions")
        isFilenameReviewPresented = false
    }

    func findBookDetailsOnline(forceRefresh: Bool = false) async {
        guard let item = selectedItem else { return }
        isLookupPresented = true
        lookupTitle = item.displayTitle
        lookupAuthor = item.displayAuthor ?? ""
        lookupISBN = item.bibliography.isbn13 ?? item.bibliography.isbn10 ?? ""
        lookupMessage = nil
        lookupCandidates = []
        if lookupISBN.isEmpty {
            isLookingUp = false
            lookupMessage = L10n.text("Confirm the title and author, then search. Only this query will be sent.")
        } else {
            await searchOpenLibrary(forceRefresh: forceRefresh)
        }
    }

    func searchOpenLibrary(forceRefresh: Bool = false) async {
        let query: MetadataLookupQuery
        do {
            if !lookupISBN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                query = .isbn(try ISBNValidator.validate(lookupISBN).isbn13)
            } else {
                let title = lookupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { throw CatalogError.openLibraryNoMatch }
                let author = lookupAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
                query = .titleAuthor(title: title, author: author.isEmpty ? nil : author)
            }
            isLookingUp = true
            lookupMessage = nil
            lookupCandidates = try await openLibrary.candidates(for: query, forceRefresh: forceRefresh)
        } catch let error as CatalogError {
            lookupCandidates = []
            lookupMessage = error.localizedDescription
        } catch {
            lookupCandidates = []
            lookupMessage = CatalogError.openLibraryUnavailable.localizedDescription
        }
        isLookingUp = false
    }

    func applyMetadataCandidate(_ candidate: MetadataCandidate, fields: Set<MetadataCandidateField>) async {
        guard var item = selectedItem else { return }
        if fields.contains(.title) { item.bibliography.title = candidate.title }
        if fields.contains(.subtitle) { item.bibliography.subtitle = candidate.subtitle }
        if fields.contains(.authors) { item.bibliography.authors = candidate.authors }
        if fields.contains(.publisher) { item.bibliography.publisher = candidate.publisher }
        if fields.contains(.publicationDate) { item.bibliography.publicationDate = candidate.publicationDate }
        if fields.contains(.originalPublicationDate) { item.bibliography.originalPublicationDate = candidate.originalPublicationDate }
        if fields.contains(.pageCount) { item.bibliography.pageCount = candidate.pageCount }
        if fields.contains(.language) { item.bibliography.languageCode = candidate.languageCodes.first }
        if fields.contains(.subjects) { item.bibliography.subjects = candidate.subjects }
        if fields.contains(.isbn10) { item.bibliography.isbn10 = candidate.isbn10 }
        if fields.contains(.isbn13) { item.bibliography.isbn13 = candidate.isbn13 }
        item.bibliography.openLibraryWorkID = candidate.openLibraryWorkID
        item.bibliography.openLibraryEditionID = candidate.openLibraryEditionID
        item.bibliography.metadataSource = provenance(adding: .openLibrary, to: item.bibliography.metadataSource)
        item.bibliography.metadataRetrievedAt = .now
        item.bibliography.metadataConfirmedByUser = true
        await saveEditedItem(item, actionName: "Add Book Details")
        isLookupPresented = false
    }

    func removeSelectedBookDetails() async {
        guard var item = selectedItem else { return }
        item.bibliography = BibliographicMetadata()
        await saveEditedItem(item, actionName: "Remove Book Details")
    }

    func searchWeb(using engine: WebSearchEngine) {
        guard let item = selectedItem else { return }
        WebSearchFallbackService.search(
            [item.displayTitle, item.displayAuthor].compactMap { $0 }.joined(separator: " "),
            using: engine
        )
    }

    func revealSelectedCover() {
        guard let url = selectedCoverURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openSelectedCover() {
        guard let url = selectedCoverURL else { return }
        NSWorkspace.shared.open(url)
    }

    var selectedCoverURL: URL? {
        guard let sourceFolderURL, let selectedItem, selectedItem.availability == .available else { return nil }
        return sourceFolderURL.appending(path: selectedItem.source.relativePath)
    }

    private func restoreLastCatalog() async {
        do {
            guard let access = try await bookmarkStore.resolveLast() else { return }
            VitrineLog.access.info("Resolved the last catalog access record")
            await openCatalog(
                at: access.catalogURL,
                rememberedFolderURL: access.coverFolderURL,
                refreshAfterOpening: true
            )
        } catch {
            VitrineLog.access.error("Failed to resolve the last catalog access record")
            statusMessage = L10n.text("Vitrine needs permission to open your last library again.")
        }
    }

    private func openCatalog(at url: URL, rememberedFolderURL: URL?, refreshAfterOpening: Bool) async {
        await performCatalogOperation(message: L10n.text("Opening catalog…"), failure: .catalogMalformed) {
            let openingLease = SecurityScopeLease(url: url)
            defer { openingLease.stop() }
            let result: CatalogParseResult
            do {
                result = try await markdownStore.read(from: url)
            } catch {
                pendingRecovery = try await recoveryService.prepareRecovery(at: url)
                isRecoveryPresented = true
                return
            }
        let remembered: URL?
        if let rememberedFolderURL {
            remembered = rememberedFolderURL
        } else {
            let access = try await bookmarkStore.resolve(catalogID: result.snapshot.catalogID)
            remembered = access?.coverFolderURL
        }
            catalog = result.snapshot
            catalogURL = url
            sourceFolderURL = remembered
            accessController.replace(catalogURL: url, coverFolderURL: remembered)
            selection = result.snapshot.items.first?.id
            saveState = result.snapshot.isReadOnly ? .readOnly : .idle
            scanState = .idle
            try await saveCoordinator.establishBaseline(result.snapshot, at: url)
            do {
                try await persistAccess(catalogURL: url, coverFolderURL: remembered, snapshot: result.snapshot)
            } catch {
                presentedError = .accessPersistenceFailed
            }
            startPresentingCatalog(at: url)
            if remembered == nil {
                statusMessage = L10n.text("Covers unavailable — folder not found")
            }
        }
        if refreshAfterOpening, canRefreshCovers { await refreshCovers(showStatus: false) }
    }

    private func reconnectMountedVolume() async {
        guard let catalog else { return }
        if let url = try? await bookmarkStore.reconnectMountedVolume(catalogID: catalog.catalogID) {
            guard let scan = try? await scan(folderURL: url),
                  folderValidator.looksLikeCatalogFolder(
                    catalog: catalog,
                    sources: scan.sources,
                    folderName: url.lastPathComponent
                  ) else {
                pendingMismatchedFolderURL = url
                isWrongFolderConfirmationPresented = true
                return
            }
            sourceFolderURL = url
            accessController.replaceCoverFolder(with: url)
            try? await persistAccess(catalogURL: try requiredCatalogURL(), coverFolderURL: url, snapshot: catalog)
            statusMessage = L10n.text("Covers restored")
            await refreshCovers(showStatus: false)
        }
    }

    private func startPresentingCatalog(at url: URL) {
        filePresenterTask?.cancel()
        filePresenter?.stop()
        let presenter = CatalogFilePresenter(url: url)
        filePresenter = presenter
        filePresenterTask = Task { [weak self] in
            for await event in presenter.events {
                guard !Task.isCancelled else { return }
                await self?.handleCatalogFileEvent(event)
            }
        }
    }

    private func handleCatalogFileEvent(_ event: CatalogFileEvent) async {
        switch event {
        case .changed:
            guard let catalogURL, let local = catalog, !isPerformingCatalogOperation else { return }
            do {
                let external = try await markdownStore.read(from: catalogURL).snapshot
                guard external != local else { return }
                let baseline = await saveCoordinator.baseline(for: catalogURL)?.parsedCatalog ?? local
                if local == baseline {
                    catalog = external
                    try await saveCoordinator.establishBaseline(external, at: catalogURL)
                    statusMessage = L10n.text("Catalog updated from disk")
                    return
                }
                guard external != baseline else { return }
                let pending = await mergeService.merge(base: baseline, local: local, external: external)
                if pending.conflicts.isEmpty {
                    try await saveCoordinator.save(pending.merged, to: catalogURL)
                    catalog = pending.merged
                    statusMessage = L10n.text("External catalog changes merged")
                } else {
                    pendingCatalogMerge = pending
                    isConflictReviewPresented = true
                    presentedError = .externalConflict
                }
            } catch {
                presentedError = .catalogMalformed
                statusMessage = L10n.text("The catalog changed on disk and needs repair. Your current library remains open.")
            }
        case .moved(let newURL):
            catalogURL = newURL
            if let catalog {
                accessController.replace(catalogURL: newURL, coverFolderURL: sourceFolderURL)
                try? await persistAccess(catalogURL: newURL, coverFolderURL: sourceFolderURL, snapshot: catalog)
                try? await saveCoordinator.establishBaseline(catalog, at: newURL)
            }
            startPresentingCatalog(at: newURL)
            statusMessage = L10n.text("Catalog location updated")
        case .deleted:
            if var snapshot = catalog {
                snapshot.isReadOnly = true
                catalog = snapshot
            }
            saveState = .readOnly
            statusMessage = L10n.text("The catalog file was removed. Restore it in Finder or open a backup.")
        case .conflictResolved, .relinquished, .reacquired:
            break
        }
    }

    private func scan(folderURL: URL) async throws -> CatalogScanResult {
        let isAccessing = folderURL.startAccessingSecurityScopedResource()
        defer { if isAccessing { folderURL.stopAccessingSecurityScopedResource() } }
        let task = Task { try await scanner.scan(folderURL: folderURL) }
        activeScanTask = task
        canCancelOperation = true
        defer {
            activeScanTask = nil
            canCancelOperation = false
        }
        return try await task.value
    }

    private func reconcile(catalog: CatalogSnapshot, folderURL: URL) async throws -> CatalogReconciliationDiff {
        let task = Task { try await scanner.reconciliationDiff(catalog: catalog, folderURL: folderURL) }
        activeReconciliationTask = task
        canCancelOperation = true
        defer {
            activeReconciliationTask = nil
            canCancelOperation = false
        }
        return try await task.value
    }

    private func apply(diff: CatalogReconciliationDiff, to snapshot: CatalogSnapshot) -> CatalogSnapshot {
        var result = snapshot
        for operation in diff.operations {
            switch operation {
            case .addRecord(let record):
                guard !result.items.contains(where: { $0.source.relativePath == record.item.source.relativePath }) else { continue }
                result.items.append(record.item)
            case .updateSource(let id, let expected, let newValue):
                guard let index = matchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].source = newValue
                result.items[index].availability = .available
            case .updatePath(let id, let expected, let newPath, let newTitle):
                guard let index = matchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].source.relativePath = newPath
                result.items[index].source.filename = (newPath as NSString).lastPathComponent
                result.items[index].source.sourceTitle = newTitle
            case .updateFinderComment(let id, let expected, let comment):
                guard let index = matchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].source.finderComment = comment
            case .markMissing(let id, let expected):
                guard let index = matchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].availability = .temporarilyUnavailable
            case .markAvailable(let id, let expected):
                guard let index = matchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].availability = .available
            case .markAmbiguous(let id, let candidates):
                if let index = result.items.firstIndex(where: { $0.id == id }) {
                    result.items[index].availability = .ambiguousMatch
                    ambiguousCandidates[id] = candidates
                }
            case .removeRecord(let id, let expected):
                guard let index = matchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items.remove(at: index)
            }
        }
        return result
    }

    private func matchingIndex(id: UUID, expected: SourceRevision, in snapshot: CatalogSnapshot) -> Int? {
        snapshot.items.firstIndex {
            $0.id == id && $0.source.relativePath == expected.relativePath &&
            $0.source.portableFingerprint == expected.portableFingerprint &&
            $0.source.fileModificationDate == expected.fileModificationDate
        }
    }

    private func registerUndo(previous: CatalogItem, actionName: String) {
        guard let undoManager = NSApp.keyWindow?.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { store in
            Task { await store.saveEditedItem(previous, actionName: actionName) }
        }
        undoManager.setActionName(actionName)
    }

    private func registerRemovalUndo(item: CatalogItem, index: Int) {
        guard let undoManager = NSApp.keyWindow?.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { store in
            Task { await store.restoreRemovedItem(item, at: index) }
        }
        undoManager.setActionName("Remove Book")
    }

    private func restoreRemovedItem(_ item: CatalogItem, at index: Int) async {
        guard var snapshot = catalog, let catalogURL, !snapshot.items.contains(where: { $0.id == item.id }) else { return }
        snapshot.items.insert(item, at: min(index, snapshot.items.count))
        snapshot.updatedAt = .now
        do {
            try await saveCoordinator.save(snapshot, to: catalogURL)
            catalog = snapshot
            selection = item.id
        } catch {
            presentedError = .coordinatedWriteFailed
        }
    }

    private func provenance(adding source: MetadataSource, to existing: MetadataSource?) -> MetadataSource {
        guard let existing else { return source }
        return existing == source ? source : .mixed
    }

    private func requiredCatalogURL() throws -> URL {
        guard let catalogURL else { throw CatalogError.catalogUnavailable }
        return catalogURL
    }

    private func persistAccess(catalogURL: URL, coverFolderURL: URL?, snapshot: CatalogSnapshot) async throws {
        do {
            try await bookmarkStore.save(catalogURL: catalogURL, coverFolderURL: coverFolderURL, snapshot: snapshot)
            VitrineLog.access.info("Persisted catalog access")
        } catch {
            VitrineLog.access.error("Failed to persist catalog access")
            throw CatalogError.accessPersistenceFailed
        }
    }

    private func performCatalogOperation(
        message: String?,
        failure fallbackError: CatalogError,
        operation: () async throws -> Void
    ) async {
        isPerformingCatalogOperation = true
        operationMessage = message
        presentedError = nil
        defer {
            isPerformingCatalogOperation = false
            operationMessage = nil
        }
        do { try await operation() }
        catch is CancellationError {
            scanState = .idle
            statusMessage = L10n.text("Refresh cancelled")
        } catch let error as CatalogError {
            presentedError = error
            saveState = .failed(error.localizedDescription)
        } catch {
            presentedError = fallbackError
            saveState = .failed(error.localizedDescription)
        }
    }

    private func searchableText(for item: CatalogItem) -> String {
        let bibliography = item.bibliography
        return SearchNormalizer.normalize([
            item.source.sourceTitle, item.source.filename, item.source.finderComment,
            bibliography.title, bibliography.subtitle, bibliography.isbn10, bibliography.isbn13,
            bibliography.publisher, bibliography.collectionName, bibliography.collectionNumber, bibliography.publicationPlace,
            bibliography.publicationDate, bibliography.originalPublicationDate, bibliography.editionDescription,
            bibliography.volumeDescription, bibliography.languageCode, bibliography.originalLanguageCode,
            bibliography.paginationStatus?.label, bibliography.description, item.personalNotes,
            bibliography.authors.joined(separator: " "), bibliography.translators.joined(separator: " "),
            bibliography.contributors.map(\.name).joined(separator: " "),
            bibliography.contributors.flatMap(\.roles).map(\.label).joined(separator: " "),
            bibliography.additionalLanguageCodes.joined(separator: " "), bibliography.physicalAttributes.map(\.label).joined(separator: " "),
            bibliography.subjects.joined(separator: " "),
        ].compactMap { $0 }.joined(separator: " "))
    }

    private func matchesFilter(_ item: CatalogItem) -> Bool {
        switch filter {
        case .all: true
        case .coversAvailable: item.availability == .available
        case .coverNotFound: item.availability != .available
        case .needsReview: item.availability == .ambiguousMatch
        case .missingISBN: item.bibliography.isbn10 == nil && item.bibliography.isbn13 == nil
        case .hasISBN: item.bibliography.isbn10 != nil || item.bibliography.isbn13 != nil
        case .detailsAdded: item.bibliography.title != nil
        case .noDetails: item.bibliography.title == nil
        }
    }

    private func areInIncreasingOrder(_ lhs: CatalogItem, _ rhs: CatalogItem) -> Bool {
        switch sortOption {
        case .titleAscending: SearchNormalizer.normalize(lhs.displayTitle) < SearchNormalizer.normalize(rhs.displayTitle)
        case .titleDescending: SearchNormalizer.normalize(lhs.displayTitle) > SearchNormalizer.normalize(rhs.displayTitle)
        case .author: SearchNormalizer.normalize(lhs.displayAuthor ?? lhs.displayTitle) < SearchNormalizer.normalize(rhs.displayAuthor ?? rhs.displayTitle)
        case .filename: lhs.source.filename.localizedStandardCompare(rhs.source.filename) == .orderedAscending
        case .publisher: SearchNormalizer.normalize(lhs.bibliography.publisher ?? lhs.displayTitle) < SearchNormalizer.normalize(rhs.bibliography.publisher ?? rhs.displayTitle)
        case .collection: SearchNormalizer.normalize(lhs.bibliography.collectionName ?? lhs.displayTitle) < SearchNormalizer.normalize(rhs.bibliography.collectionName ?? rhs.displayTitle)
        case .dateAdded: lhs.dateAdded < rhs.dateAdded
        case .coverFileModified: (lhs.source.fileModificationDate ?? .distantPast) < (rhs.source.fileModificationDate ?? .distantPast)
        case .recentlyUpdated: lhs.dateModified > rhs.dateModified
        }
    }

}
