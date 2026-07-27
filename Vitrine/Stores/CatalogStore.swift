import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class CatalogStore {
    private let scanner = CatalogScanner()
    private let reconciler = CatalogReconciler()
    private let markdownStore = CatalogMarkdownStore()
    private let saveCoordinator: CatalogSaveCoordinator
    private let bookmarkStore = SecurityScopedBookmarkStore.shared
    private let folderValidator = SourceFolderValidator()
    private let filenameParser = FilenameMetadataParser()
    private let filenameSuggestionAdapter = FilenameMetadataSuggestionAdapter()
    private let openLibrary = OpenLibraryService()
    private let mergeService = CatalogMergeService()
    private let recoveryService = CatalogRecoveryService()
    private let accessController = SecurityScopedAccessController()
    private let healthService = CatalogHealthService()
    private let diagnosticService = CatalogDiagnosticService()
    private let coverInformationRebuilder = CatalogCoverInformationRebuilder()
    private let uiTestFixtureBuilder = CatalogUITestFixtureBuilder()

    var catalog: CatalogSnapshot? {
        didSet { derivedIndex.removeAll() }
    }
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
    var catalogDiagnostics: [MarkdownDiagnostic] = []
    var catalogHealthReport: CatalogHealthReport?
    var isCatalogHealthReportPresented = false
    var filenameSuggestion: FilenameMetadataSuggestion?
    var isFilenameReviewPresented = false
    private(set) var shouldContinueFilenameReviewAfterDismissal = false
    var isMetadataEditorPresented = false
    var isLookupPresented = false
    var lookupCandidates: [MetadataCandidate] = []
    var isLookingUp = false
    var lookupMessage: String?
    var lookupTitle = ""
    var lookupAuthor = ""
    var lookupISBN = ""
    var pendingCatalogMerge: PendingCatalogMerge?
    var isConflictChoicePresented = false
    var isConflictReviewPresented = false
    var ambiguousCandidates: [UUID: [FileCandidate]] = [:]
    var isAmbiguousReviewPresented = false
    var pendingMismatchedFolderURL: URL?
    var isWrongFolderConfirmationPresented = false
    var pendingRecovery: CatalogRecoveryCandidate?
    var isRecoveryPresented = false
    var backupRestoreOptions: [CatalogRecoveryBackupOption] = []
    var isBackupRestorePresented = false
    var pendingRemovalItemID: CatalogItem.ID?
    var isRemovalConfirmationPresented = false
    var focusSearchRequest = 0
    var bookDetailsExpansionRequest = 0
    private(set) var canCancelOperation = false

    private var hasStarted = false
    @ObservationIgnored private var filePresenter: CatalogFilePresenter?
    @ObservationIgnored private var filePresenterTask: Task<Void, Never>?
    @ObservationIgnored private var statusClearTask: Task<Void, Never>?
    @ObservationIgnored private var allowSourceFolderMismatchOnce = false
    @ObservationIgnored private var activeScanTask: Task<CatalogScanResult, any Error>?
    @ObservationIgnored private var activeReconciliationTask: Task<CatalogReconciliationDiff, any Error>?
    @ObservationIgnored private var isPerformingBackgroundCatalogOperation = false
    @ObservationIgnored private var lastForegroundRefreshAt: Date?
    @ObservationIgnored private var catalogOperationWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var pendingEditedCatalog: CatalogSnapshot?
    @ObservationIgnored private var deferredFilenameSuggestionUndo: DeferredItemUndo?
    @ObservationIgnored private var filenameSuggestionUndoManager: UndoManager?
    @ObservationIgnored private var pendingRecoveryCoverFolderURL: URL?
    @ObservationIgnored private var forceLookupRefreshOnPresentation = false
    @ObservationIgnored private var derivedIndex = CatalogDerivedIndex()
    @ObservationIgnored private let undoManagerProvider: () -> UndoManager?

    init(
        saveCoordinator: CatalogSaveCoordinator = CatalogSaveCoordinator(),
        catalogURL: URL? = nil,
        sourceFolderURL: URL? = nil,
        undoManagerProvider: @escaping () -> UndoManager? = { NSApp.keyWindow?.undoManager }
    ) {
        self.saveCoordinator = saveCoordinator
        self.catalogURL = catalogURL
        self.sourceFolderURL = sourceFolderURL
        self.undoManagerProvider = undoManagerProvider
    }

    var canRefreshCovers: Bool {
        catalog != nil && catalog?.isReadOnly == false && sourceFolderURL != nil && !catalogOperationIsActive
    }

    var isBrowsingWithoutCovers: Bool {
        catalog != nil && sourceFolderURL == nil
    }

    var visibleItems: [CatalogItem] {
        guard let catalog else { return [] }
        let query = SearchNormalizer.normalize(searchText)
        derivedIndex.prepare(
            for: catalog.items,
            sortOption: sortOption,
            includingSearchText: !query.isEmpty
        )
        let filtered = catalog.items.filter { item in
            matchesFilter(item) &&
                (query.isEmpty || derivedIndex.entry(for: item.id)?.searchableText?.contains(query) == true)
        }
        return filtered.sorted(by: areInIncreasingOrder)
    }

    var selectedItem: CatalogItem? {
        guard let selection else { return nil }
        return catalog?.items.first { $0.id == selection }
    }

    var pendingRemovalItem: CatalogItem? {
        guard let pendingRemovalItemID else { return nil }
        return catalog?.items.first { $0.id == pendingRemovalItemID }
    }

    var filenameReviewCount: Int {
        catalog?.items.lazy.filter(needsFilenameReview).count ?? 0
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        if configureUITestFixtureIfRequested() { return }
        guard Self.shouldRestoreLastCatalog() else { return }
        await restoreLastCatalog()
    }

    private func configureUITestFixtureIfRequested() -> Bool {
        guard let fixture = uiTestFixtureBuilder.build() else { return false }
        catalog = fixture.snapshot
        catalogDiagnostics = fixture.diagnostics
        selection = nil
        sourceFolderURL = fixture.sourceFolderURL
        saveState = fixture.snapshot.isReadOnly ? .readOnly : .idle
        pendingCatalogMerge = fixture.pendingMerge
        pendingRecovery = fixture.pendingRecovery

        if fixture.pendingMerge != nil {
            isConflictChoicePresented = true
        }
        if fixture.pendingRecovery != nil {
            isRecoveryPresented = true
        }
        return true
    }

    nonisolated static func shouldRestoreLastCatalog(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        !arguments.contains("-VitrineSkipRestoreLastCatalog") &&
            environment["VITRINE_UNIT_TESTING"] != "1" &&
            environment["XCTestConfigurationFilePath"] == nil
    }

    func applicationBecameActive() async {
        guard catalog != nil else { return }
        let now = Date.now
        if let lastForegroundRefreshAt,
           now.timeIntervalSince(lastForegroundRefreshAt) < 1.5 {
            return
        }
        lastForegroundRefreshAt = now
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
            await handleSaveFailure(error)
        }
    }

    func exportCatalogCopy() async {
        guard let catalog,
              let destination = CatalogPanelService.chooseCatalogCopyDestination(catalogName: catalog.name) else { return }
        do {
            var copy = catalog
            copy.isReadOnly = false
            try await saveCoordinator.save(
                copy,
                to: destination,
                reason: .export,
                replacementPolicy: .replaceExistingDestination
            )
            statusMessage = L10n.text("Catalog copy exported")
        } catch {
            presentedError = .coordinatedWriteFailed
        }
    }

    func showLocalBackups() async {
        guard catalog != nil else { return }
        do {
            let archiveURL = try await saveCoordinator.recoveryArchiveURL()
            NSWorkspace.shared.activateFileViewerSelecting([archiveURL])
        } catch {
            presentedError = .catalogUnavailable
        }
    }

    func checkCatalogHealth() async {
        guard let catalog else { return }
        let backups = (try? await saveCoordinator.backups(catalogID: catalog.catalogID)) ?? []
        catalogHealthReport = healthService.report(
            catalog: catalog,
            diagnostics: catalogDiagnostics,
            backups: backups
        )
        isCatalogHealthReportPresented = true
    }

    func exportDiagnosticReport() async {
        guard let catalog,
              let destination = CatalogPanelService.chooseDiagnosticReportDestination() else { return }
        let backups = (try? await saveCoordinator.backups(catalogID: catalog.catalogID)) ?? []
        let health = healthService.report(
            catalog: catalog,
            diagnostics: catalogDiagnostics,
            backups: backups
        )
        let report = diagnosticService.report(
            catalog: catalog,
            health: health,
            diagnostics: catalogDiagnostics,
            scanWarnings: scanWarnings
        )
        do {
            try Data(report.utf8).write(to: destination, options: .atomic)
            statusMessage = L10n.text("Privacy-safe diagnostic report exported")
        } catch {
            presentedError = .coordinatedWriteFailed
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

    @discardableResult
    func createCatalog() async -> Bool {
        guard !catalogOperationIsActive,
              let folderURL = CatalogPanelService.chooseCoverFolder(),
              let destinationURL = CatalogPanelService.chooseCatalogDestination(for: folderURL) else { return false }

        var didCreateCatalog = false
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
            try await saveCoordinator.save(
                snapshot,
                to: destinationURL,
                replacementPolicy: .replaceExistingDestination
            )
            accessController.replace(catalogURL: destinationURL, coverFolderURL: folderURL)
            try await persistAccess(catalogURL: destinationURL, coverFolderURL: folderURL, snapshot: snapshot)
            catalog = snapshot
            catalogDiagnostics = []
            catalogURL = destinationURL
            sourceFolderURL = folderURL
            startPresentingCatalog(at: destinationURL)
            selection = snapshot.items.first?.id
            scanWarnings = scan.warnings
            saveState = .saved(.now)
            scanState = .completed(warnings: scan.warnings.count)
            didCreateCatalog = true
        }
        return didCreateCatalog
    }

    func openCatalog() async {
        guard !catalogOperationIsActive,
              let selectedURL = CatalogPanelService.chooseCatalogToOpen() else { return }
        await openCatalog(at: selectedURL, rememberedFolderURL: nil, refreshAfterOpening: true)
    }

    func restorePendingRecovery(backupID: URL) async {
        guard let recovery = pendingRecovery,
              let backup = recovery.backupOptions.first(where: { $0.id == backupID })?.backup,
              let catalogID = recovery.catalogID,
              !catalogOperationIsActive else { return }
        let rememberedFolderURL = pendingRecoveryCoverFolderURL
        isRecoveryPresented = false
        await performCatalogOperation(message: L10n.text("Restoring catalog backup…"), failure: .coordinatedWriteFailed) {
            try await saveCoordinator.restore(
                backup,
                to: recovery.damagedCatalogURL,
                catalogID: catalogID,
                preservingDamagedCurrentCatalog: true
            )
            pendingRecovery = nil
        }
        guard pendingRecovery == nil else {
            isRecoveryPresented = true
            return
        }
        pendingRecoveryCoverFolderURL = nil
        statusMessage = L10n.text("The damaged catalog was preserved and the selected backup was restored.")
        await openCatalog(
            at: recovery.damagedCatalogURL,
            rememberedFolderURL: rememberedFolderURL,
            refreshAfterOpening: true
        )
    }

    func openRecoveredCatalog() {
        guard let recovery = pendingRecovery,
              var recovered = recovery.recoveredCatalog?.snapshot,
              !recovered.items.isEmpty else { return }
        recovered.isReadOnly = true
        filePresenterTask?.cancel()
        filePresenter?.stop()
        filePresenter = nil
        catalog = recovered
        catalogDiagnostics = recovery.recoveredCatalog?.diagnostics ?? []
        catalogURL = recovery.damagedCatalogURL
        sourceFolderURL = pendingRecoveryCoverFolderURL
        accessController.replace(catalogURL: recovery.damagedCatalogURL, coverFolderURL: sourceFolderURL)
        selection = recovered.items.first?.id
        saveState = .readOnly
        scanState = .idle
        pendingRecovery = nil
        pendingRecoveryCoverFolderURL = nil
        isRecoveryPresented = false
        statusMessage = L10n.text("Recovered records opened read-only; the damaged catalog was not replaced.")
    }

    func revealPendingRecoveryBackup(_ backupID: URL) {
        guard let backup = pendingRecovery?.backupOptions.first(where: { $0.id == backupID })?.backup else { return }
        NSWorkspace.shared.activateFileViewerSelecting([backup.url])
    }

    func revealDamagedCatalog() {
        guard let url = pendingRecovery?.preservedDamagedCopyURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func exportRecoveryDiagnostics() {
        guard let recovery = pendingRecovery,
              let destination = CatalogPanelService.chooseDiagnosticReportDestination() else { return }
        do {
            let report = recoveryService.diagnosticReport(for: recovery)
            try Data(report.utf8).write(to: destination, options: .atomic)
            statusMessage = L10n.text("Privacy-safe technical report exported")
        } catch {
            presentedError = .coordinatedWriteFailed
        }
    }

    func createNewCatalogAfterRecovery() async {
        isRecoveryPresented = false
        if await createCatalog() {
            pendingRecovery = nil
            pendingRecoveryCoverFolderURL = nil
        } else {
            isRecoveryPresented = pendingRecovery != nil
        }
    }

    func cancelPendingRecovery() {
        pendingRecovery = nil
        pendingRecoveryCoverFolderURL = nil
        isRecoveryPresented = false
    }

    func locateCoverFolder() async {
        guard let currentCatalog = catalog,
              !catalogOperationIsActive,
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
              !catalogOperationIsActive,
              pendingEditedCatalog == nil else { return }

        await performCatalogOperation(
            message: showStatus ? L10n.text("Refreshing covers…") : nil,
            failure: .folderEnumerationFailed
        ) {
            scanState = .refreshing(completed: 0, total: nil)
            let diff: CatalogReconciliationDiff
            do {
                diff = try await reconcile(catalog: currentCatalog, folderURL: folderURL)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if !showStatus {
                    sourceFolderURL = nil
                    accessController.replaceCoverFolder(with: nil)
                    scanState = .idle
                    statusMessage = L10n.text("Covers unavailable — folder not found")
                    return
                }
                throw error
            }
            guard diff.baseCatalogID == currentCatalog.catalogID else { throw CatalogError.sourceFolderMismatch }
            let acceptedMismatchedFolder = allowSourceFolderMismatchOnce
            guard diff.sourceFolderValidated || acceptedMismatchedFolder else {
                pendingMismatchedFolderURL = folderURL
                isWrongFolderConfirmationPresented = true
                sourceFolderURL = nil
                accessController.replaceCoverFolder(with: nil)
                scanState = .idle
                return
            }
            allowSourceFolderMismatchOnce = false
            guard let latestCatalog = catalog,
                  latestCatalog.catalogID == currentCatalog.catalogID else {
                return
            }
            guard latestCatalog.updatedAt == diff.baseCatalogUpdatedAt else {
                scanState = .idle
                statusMessage = L10n.text("The library changed while covers were refreshing. Refresh again to apply the latest cover changes.")
                return
            }
            let allowAutomaticRemovals = diff.sourceFolderValidated &&
                diff.completedEnumeration && diff.warnings.isEmpty
            var refreshed = apply(
                diff: diff,
                to: latestCatalog,
                allowRemovals: allowAutomaticRemovals
            )
            refreshed.sourceFolderName = folderURL.lastPathComponent
            refreshed.sourceFolderSignature = folderValidator.signature(
                folderName: folderURL.lastPathComponent,
                sources: diff.scannedSources,
                catalogID: refreshed.catalogID
            )
            let hasCatalogChanges = Self.refreshRequiresSave(current: latestCatalog, proposed: refreshed)
            scanWarnings = diff.warnings.map { CatalogScanWarning(relativePath: "", message: $0) }
            scanState = .completed(warnings: diff.warnings.count)
            statusMessage = diff.warnings.first
            guard hasCatalogChanges else { return }
            saveState = .saving
            refreshed.updatedAt = .now
            catalog = refreshed
            if let selection, !refreshed.items.contains(where: { $0.id == selection }) {
                self.selection = refreshed.items.first?.id
            }
            try await saveCoordinator.save(refreshed, to: catalogURL, reason: .refresh)
            saveState = .saved(.now)
            do {
                try await persistAccess(catalogURL: catalogURL, coverFolderURL: folderURL, snapshot: refreshed)
            } catch {
                presentedError = .accessPersistenceFailed
            }
        }
    }

    func rebuildCoverInformation() async {
        guard let currentCatalog = catalog,
              !currentCatalog.isReadOnly,
              let folderURL = sourceFolderURL,
              let catalogURL,
              !catalogOperationIsActive,
              pendingEditedCatalog == nil else { return }

        await performCatalogOperation(
            message: L10n.text("Rebuilding cover information…"),
            failure: .folderEnumerationFailed
        ) {
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

            var rebuild = coverInformationRebuilder.rebuild(
                catalog: currentCatalog,
                scannedSources: scan.sources
            )
            rebuild.snapshot.sourceFolderName = folderURL.lastPathComponent
            rebuild.snapshot.sourceFolderSignature = folderValidator.signature(
                folderName: folderURL.lastPathComponent,
                sources: scan.sources,
                catalogID: rebuild.snapshot.catalogID
            )
            scanWarnings = scan.warnings
            scanState = .completed(warnings: scan.warnings.count)

            guard Self.refreshRequiresSave(current: currentCatalog, proposed: rebuild.snapshot) else {
                statusMessage = String(localized: "Cover information is current for \(rebuild.refreshedRecordCount) books.")
                return
            }
            rebuild.snapshot.updatedAt = .now
            try await saveCoordinator.save(rebuild.snapshot, to: catalogURL, reason: .refresh)
            catalog = rebuild.snapshot
            saveState = .saved(.now)
            statusMessage = String(localized: "Cover information rebuilt for \(rebuild.refreshedRecordCount) books.")
        }
    }

    @discardableResult
    func saveEditedItem(
        _ editedItem: CatalogItem,
        actionName: String = "Edit Book Details",
        reason: CatalogSaveReason = .metadataEdit,
        deferUndoRegistration: Bool = false
    ) async -> Bool {
        await waitForCatalogOperationToFinish()
        guard var snapshot = pendingEditedCatalog ?? catalog,
              !snapshot.isReadOnly, let catalogURL,
              let index = snapshot.items.firstIndex(where: { $0.id == editedItem.id }) else { return false }
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
        pendingEditedCatalog = snapshot
        do {
            saveState = .saving
            let savedSnapshot = try await saveCoordinator.save(snapshot, to: catalogURL, reason: reason)
            catalog = savedSnapshot
            if pendingEditedCatalog == savedSnapshot {
                pendingEditedCatalog = nil
            }
            if deferUndoRegistration {
                deferredFilenameSuggestionUndo = DeferredItemUndo(
                    previous: previous,
                    actionName: actionName
                )
            } else {
                registerUndo(previous: previous, actionName: actionName)
            }
            saveState = .saved(.now)
            return true
        } catch {
            if pendingEditedCatalog == snapshot {
                pendingEditedCatalog = nil
            }
            let recovered = await handleSaveFailure(error, localCandidate: snapshot)
            if recovered {
                if deferUndoRegistration {
                    deferredFilenameSuggestionUndo = DeferredItemUndo(
                        previous: previous,
                        actionName: actionName
                    )
                } else {
                    registerUndo(previous: previous, actionName: actionName)
                }
            }
            return recovered
        }
    }

    func flushPendingSaves() async throws {
        try await saveCoordinator.flushPendingSaves()
    }

    func requestBookRemoval(itemID: CatalogItem.ID? = nil) {
        guard let snapshot = catalog, !snapshot.isReadOnly,
              let requestedID = itemID ?? selection,
              snapshot.items.contains(where: { $0.id == requestedID }) else { return }
        pendingRemovalItemID = requestedID
        isRemovalConfirmationPresented = true
    }

    func cancelBookRemoval() {
        pendingRemovalItemID = nil
        isRemovalConfirmationPresented = false
    }

    @discardableResult
    func confirmBookRemoval() async -> Bool {
        guard var snapshot = catalog, !snapshot.isReadOnly,
              let requestedID = pendingRemovalItemID,
              let catalogURL,
              let index = snapshot.items.firstIndex(where: { $0.id == requestedID }) else { return false }
        let removed = snapshot.items.remove(at: index)
        snapshot.updatedAt = .now
        do {
            try await saveCoordinator.save(snapshot, to: catalogURL)
            catalog = snapshot
            if selection == requestedID {
                selection = snapshot.items.isEmpty
                    ? nil
                    : snapshot.items[min(index, snapshot.items.count - 1)].id
            }
            pendingRemovalItemID = nil
            isRemovalConfirmationPresented = false
            registerRemovalUndo(item: removed, index: index)
            statusMessage = L10n.text("Book removed from catalog; cover file unchanged")
            return true
        } catch {
            await handleSaveFailure(error)
            return false
        }
    }

    func restoreLatestBackup() async {
        guard let current = catalog, !catalogOperationIsActive else { return }
        do {
            var options: [CatalogRecoveryBackupOption] = []
            for backup in try await saveCoordinator.backups(catalogID: current.catalogID) {
                guard let parsed = try? await markdownStore.read(from: backup.url),
                      parsed.snapshot.catalogID == current.catalogID,
                      !parsed.snapshot.isReadOnly else { continue }
                options.append(CatalogRecoveryBackupOption(backup: backup, parsedCatalog: parsed))
            }
            guard !options.isEmpty else {
                statusMessage = L10n.text("No catalog backups are available.")
                return
            }
            backupRestoreOptions = options
            isBackupRestorePresented = true
        } catch {
            presentedError = .catalogUnavailable
        }
    }

    @discardableResult
    func restoreBackup(_ backupID: URL) async -> Bool {
        guard let current = catalog,
              let catalogURL,
              let option = backupRestoreOptions.first(where: { $0.id == backupID }),
              !catalogOperationIsActive else { return false }
        var restoredSuccessfully = false
        await performCatalogOperation(message: L10n.text("Restoring selected backup…"), failure: .coordinatedWriteFailed) {
            let previous = current
            let restored = try await saveCoordinator.restore(
                option.backup,
                to: catalogURL,
                catalogID: current.catalogID
            )
            catalog = restored
            catalogDiagnostics = option.parsedCatalog.diagnostics
            if let selection, restored.items.contains(where: { $0.id == selection }) {
                self.selection = selection
            } else {
                selection = restored.items.first?.id
            }
            registerCatalogUndo(previous: previous, actionName: "Restore Catalog Backup")
            statusMessage = L10n.text("Selected catalog backup restored")
            restoredSuccessfully = true
        }
        if restoredSuccessfully {
            isBackupRestorePresented = false
            backupRestoreOptions = []
        }
        return restoredSuccessfully
    }

    @discardableResult
    func resolveCatalogConflicts(useExternal conflictIDs: Set<UUID>) async -> Bool {
        guard let pendingCatalogMerge, let catalogURL, let previous = catalog else { return false }
        let resolved = await mergeService.resolving(pendingCatalogMerge, useExternal: conflictIDs)
        do {
            saveState = .saving
            try await saveCoordinator.save(resolved, to: catalogURL, reason: .conflictResolution)
            catalog = resolved
            self.pendingCatalogMerge = nil
            isConflictReviewPresented = false
            saveState = .saved(.now)
            statusMessage = L10n.text("Catalog conflicts resolved")
            registerCatalogUndo(previous: previous, actionName: "Resolve Catalog Conflicts")
            return true
        } catch {
            await handleSaveFailure(error)
            return false
        }
    }

    func keepMyCatalogChanges() async {
        isConflictChoicePresented = false
        await resolveCatalogConflicts(useExternal: [])
    }

    func useChangesFromOtherMac() async {
        guard let pendingCatalogMerge else { return }
        isConflictChoicePresented = false
        await resolveCatalogConflicts(useExternal: Set(pendingCatalogMerge.conflicts.map(\.id)))
    }

    func reviewCatalogChanges() {
        isConflictChoicePresented = false
        isConflictReviewPresented = true
    }

    func keepBrowsingWithCatalogConflict() {
        isConflictChoicePresented = false
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
        shouldContinueFilenameReviewAfterDismissal = false
        deferredFilenameSuggestionUndo = nil
        filenameSuggestionUndoManager = undoManagerProvider()
        filenameSuggestion = filenameParser.suggestions(from: selectedItem.source.sourceTitle)
        isFilenameReviewPresented = true
    }

    func showBooksNeedingFilenameReview() {
        searchText = ""
        filter = .needsReview
        if let selection,
           catalog?.items.first(where: { $0.id == selection }).map(needsFilenameReview) != true {
            self.selection = nil
        }
    }

    func reviewNextFilename() {
        if filter != .needsReview {
            showBooksNeedingFilenameReview()
        }
        guard catalog?.isReadOnly == false,
              let item = visibleItems.first else {
            statusMessage = L10n.text("All filenames have been reviewed")
            return
        }
        selection = item.id
        suggestDetailsFromFilename()
    }

    @discardableResult
    func applyFilenameSuggestion(
        _ suggestion: FilenameMetadataSuggestion,
        to itemID: CatalogItem.ID,
        continueToNext: Bool = false
    ) async -> Bool {
        guard let existing = catalog?.items.first(where: { $0.id == itemID }) else { return false }
        let item = filenameSuggestionAdapter.applying(suggestion, to: existing)
        let saved = await saveEditedItem(
            item,
            actionName: "Accept Filename Suggestions",
            reason: .explicit,
            deferUndoRegistration: true
        )
        if saved {
            shouldContinueFilenameReviewAfterDismissal = continueToNext
            bookDetailsExpansionRequest += 1
            statusMessage = L10n.text("Book details saved")
            VitrineLog.catalog.info("Saved accepted filename suggestions")
        }
        return saved
    }

    func finishFilenameSuggestionReviewPresentation() {
        let continueToNext = shouldContinueFilenameReviewAfterDismissal
        shouldContinueFilenameReviewAfterDismissal = false
        guard let deferredFilenameSuggestionUndo,
              let filenameSuggestionUndoManager else {
            self.filenameSuggestionUndoManager = nil
            continueFilenameReviewIfNeeded(continueToNext)
            return
        }
        self.deferredFilenameSuggestionUndo = nil
        self.filenameSuggestionUndoManager = nil

        DispatchQueue.main.async { [weak self] in
            self?.registerUndo(
                previous: deferredFilenameSuggestionUndo.previous,
                actionName: deferredFilenameSuggestionUndo.actionName,
                using: filenameSuggestionUndoManager
            )
        }
        continueFilenameReviewIfNeeded(continueToNext)
    }

    private func continueFilenameReviewIfNeeded(_ shouldContinue: Bool) {
        guard shouldContinue else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self?.reviewNextFilename()
        }
    }

    func findBookDetailsOnline(forceRefresh: Bool = false) async {
        guard let item = selectedItem else { return }
        lookupTitle = item.displayTitle
        lookupAuthor = item.displayAuthor ?? ""
        lookupISBN = item.bibliography.isbn13 ?? item.bibliography.isbn10 ?? ""
        lookupMessage = nil
        lookupCandidates = []
        isLookingUp = false
        forceLookupRefreshOnPresentation = forceRefresh
        isLookupPresented = true
    }

    func prefetchOpenLibraryIfNeeded() async {
        guard isLookupPresented, !isLookingUp, lookupCandidates.isEmpty else { return }
        let hasISBN = !lookupISBN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasTitle = !lookupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasISBN || hasTitle else {
            lookupMessage = L10n.text("Confirm the title and author, then search. Only this query will be sent.")
            return
        }
        let forceRefresh = forceLookupRefreshOnPresentation
        forceLookupRefreshOnPresentation = false
        await searchOpenLibrary(forceRefresh: forceRefresh)
    }

    func searchOpenLibrary(forceRefresh: Bool = false) async {
        guard !isLookingUp else { return }
        let query: MetadataLookupQuery
        isLookingUp = true
        lookupMessage = nil
        defer { isLookingUp = false }
        do {
            if !lookupISBN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                query = .isbn(try ISBNValidator.validate(lookupISBN).isbn13)
            } else {
                let title = lookupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { throw CatalogError.openLibraryNoMatch }
                let author = lookupAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
                query = .titleAuthor(title: title, author: author.isEmpty ? nil : author)
            }
            lookupCandidates = try await openLibrary.candidates(for: query, forceRefresh: forceRefresh)
        } catch is CancellationError {
            return
        } catch let error as CatalogError {
            lookupCandidates = []
            lookupMessage = error.localizedDescription
        } catch {
            lookupCandidates = []
            lookupMessage = CatalogError.openLibraryUnavailable.localizedDescription
        }
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
        guard let url = resolveSelectedCoverURL(reportingFailure: true) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openSelectedCover() {
        guard let url = resolveSelectedCoverURL(reportingFailure: true) else { return }
        NSWorkspace.shared.open(url)
    }

    func quickLookSelectedCover() {
        guard let url = resolveSelectedCoverURL(reportingFailure: true) else { return }
        QuickLookService.shared.show(url: url)
    }

    var selectedCoverURL: URL? {
        resolveSelectedCoverURL(reportingFailure: false)
    }

    private func resolveSelectedCoverURL(reportingFailure: Bool) -> URL? {
        guard let sourceFolderURL, let selectedItem, selectedItem.availability == .available else { return nil }
        do {
            return try CoverPathResolver().resolve(
                relativePath: selectedItem.source.relativePath,
                inside: sourceFolderURL
            )
        } catch {
            if reportingFailure { presentedError = .invalidCoverPath }
            return nil
        }
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
        let rememberedCatalogID = try? await bookmarkStore.catalogID(matching: url)
        var didOpenCatalog = false
        await performCatalogOperation(message: L10n.text("Opening catalog…"), failure: .catalogMalformed) {
            let openingLease = SecurityScopeLease(url: url)
            defer { openingLease.stop() }
            let result: CatalogParseResult
            do {
                result = try await markdownStore.read(from: url)
            } catch {
                pendingRecovery = try await recoveryService.prepareRecovery(
                    at: url,
                    rememberedCatalogID: rememberedCatalogID
                )
                pendingRecoveryCoverFolderURL = rememberedFolderURL
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
            if result.hasUnrecoverableErrors {
                pendingRecovery = try await recoveryService.prepareRecovery(
                    at: url,
                    rememberedCatalogID: result.snapshot.catalogID
                )
                pendingRecoveryCoverFolderURL = remembered
                isRecoveryPresented = true
                return
            }
            catalog = result.snapshot
            catalogDiagnostics = result.diagnostics
            catalogURL = url
            sourceFolderURL = remembered
            accessController.replace(catalogURL: url, coverFolderURL: remembered)
            selection = result.snapshot.items.first?.id
            saveState = result.snapshot.isReadOnly ? .readOnly : .idle
            scanState = .idle
            try await saveCoordinator.establishBaseline(result.snapshot, at: url)
            do {
                try await persistAccess(
                    catalogURL: url,
                    coverFolderURL: remembered,
                    snapshot: result.snapshot,
                    preserveExistingCoverAccess: remembered == nil
                )
            } catch {
                presentedError = .accessPersistenceFailed
            }
            startPresentingCatalog(at: url)
            if remembered == nil {
                statusMessage = L10n.text("Covers unavailable — folder not found")
            } else if result.diagnostics.contains(where: { $0.severity == .error }) {
                statusMessage = L10n.text("Your catalog needs minor repairs.")
            }
            didOpenCatalog = true
        }
        if didOpenCatalog, refreshAfterOpening, canRefreshCovers { await refreshCovers(showStatus: false) }
    }

    private func reconnectMountedVolume() async {
        guard let catalog else { return }
        let resolvedAccess = try? await bookmarkStore.resolve(catalogID: catalog.catalogID)
        var candidateURL = resolvedAccess?.coverFolderURL
        if candidateURL == nil {
            candidateURL = try? await bookmarkStore.reconnectMountedVolume(catalogID: catalog.catalogID)
        }
        guard let url = candidateURL,
              let scan = try? await scan(folderURL: url) else { return }
        guard folderValidator.looksLikeCatalogFolder(
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
        await waitForCatalogOperationToFinish()
        await waitForPendingEditedSaveToFinish()
        await processCatalogFileEvent(event)
    }

    private func waitForPendingEditedSaveToFinish() async {
        while pendingEditedCatalog != nil {
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    @discardableResult
    private func processCatalogFileEvent(
        _ event: CatalogFileEvent,
        localCandidate: CatalogSnapshot? = nil
    ) async -> Bool {
        switch event {
        case .changed:
            guard let catalogURL, let displayedCatalog = catalog else { return false }
            let local = localCandidate ?? displayedCatalog
            do {
                let externalResult = try await markdownStore.read(from: catalogURL)
                let external = externalResult.snapshot
                guard external != local else {
                    if localCandidate != nil {
                        catalog = external
                    }
                    return true
                }
                let baseline = await saveCoordinator.baseline(for: catalogURL)?.parsedCatalog ?? local
                if local == baseline {
                    try await saveCoordinator.establishBaseline(
                        external,
                        at: catalogURL,
                        expectedContentDigest: externalResult.contentDigest
                    )
                    catalog = external
                    statusMessage = L10n.text("Catalog updated from disk")
                    return true
                }
                if external == baseline {
                    guard localCandidate != nil else { return true }
                    try await saveCoordinator.establishBaseline(
                        external,
                        at: catalogURL,
                        expectedContentDigest: externalResult.contentDigest
                    )
                    try await saveCoordinator.save(local, to: catalogURL)
                    catalog = local
                    return true
                }
                let pending = await mergeService.merge(base: baseline, local: local, external: external)
                try await saveCoordinator.establishBaseline(
                    external,
                    at: catalogURL,
                    expectedContentDigest: externalResult.contentDigest
                )
                if pending.conflicts.isEmpty {
                    try await saveCoordinator.save(pending.merged, to: catalogURL)
                    catalog = pending.merged
                    statusMessage = L10n.text("External catalog changes merged")
                    return true
                } else {
                    pendingCatalogMerge = pending
                    isConflictChoicePresented = true
                    presentedError = nil
                    return false
                }
            } catch {
                // File presenters can observe a replacement before every filesystem view has
                // settled. Keep the valid in-memory catalog usable and wait for the next event.
                presentedError = nil
                statusMessage = L10n.text("Catalog changes could not be read yet. Your current library remains open.")
                return false
            }
        case .moved(let newURL):
            catalogURL = newURL
            if let catalog {
                accessController.replace(catalogURL: newURL, coverFolderURL: sourceFolderURL)
                try? await persistAccess(
                    catalogURL: newURL,
                    coverFolderURL: sourceFolderURL,
                    snapshot: catalog,
                    preserveExistingCoverAccess: sourceFolderURL == nil
                )
                try? await saveCoordinator.establishBaseline(catalog, at: newURL)
            }
            startPresentingCatalog(at: newURL)
            statusMessage = L10n.text("Catalog location updated")
            return true
        case .deleted:
            try? await Task.sleep(for: .milliseconds(300))
            if let catalogURL,
               (try? catalogURL.checkResourceIsReachable()) == true {
                return await processCatalogFileEvent(.changed)
            }
            if var snapshot = catalog {
                snapshot.isReadOnly = true
                catalog = snapshot
            }
            saveState = .readOnly
            statusMessage = L10n.text("The catalog file was removed. Restore it in Finder or open a backup.")
            return true
        case .conflictResolved:
            return await processCatalogFileEvent(.changed)
        case .relinquished, .reacquired:
            return true
        }
    }

    private func waitForCatalogOperationToFinish() async {
        guard catalogOperationIsActive else { return }
        await withCheckedContinuation { continuation in
            catalogOperationWaiters.append(continuation)
        }
    }

    private func resumeCatalogFileEventWaiters() {
        let waiters = catalogOperationWaiters
        catalogOperationWaiters.removeAll(keepingCapacity: true)
        waiters.forEach { $0.resume() }
    }

    private func scan(folderURL: URL) async throws -> CatalogScanResult {
        let isAccessing = folderURL.startAccessingSecurityScopedResource()
        defer { if isAccessing { folderURL.stopAccessingSecurityScopedResource() } }
        let task = Task {
            try await scanner.scan(folderURL: folderURL) { [weak self] progress in
                await self?.reportScanProgress(progress)
            }
        }
        activeScanTask = task
        canCancelOperation = true
        defer {
            activeScanTask = nil
            canCancelOperation = false
            clearTransientScanProgress()
        }
        return try await task.value
    }

    private func reconcile(catalog: CatalogSnapshot, folderURL: URL) async throws -> CatalogReconciliationDiff {
        let task = Task {
            try await scanner.reconciliationDiff(catalog: catalog, folderURL: folderURL) { [weak self] progress in
                await self?.reportScanProgress(progress)
            }
        }
        activeReconciliationTask = task
        canCancelOperation = true
        defer {
            activeReconciliationTask = nil
            canCancelOperation = false
            clearTransientScanProgress()
        }
        return try await task.value
    }

    private func clearTransientScanProgress() {
        guard case .refreshing = scanState else { return }
        scanState = .idle
    }

    private func reportScanProgress(_ progress: CatalogScanProgress) {
        scanState = .refreshing(completed: progress.completed, total: progress.total)
        if isPerformingCatalogOperation {
            operationMessage = progress.total > 0
                ? String(localized: "Scanning covers \(progress.completed) of \(progress.total)…")
                : L10n.text("Scanning covers…")
        }
    }

    func apply(
        diff: CatalogReconciliationDiff,
        to snapshot: CatalogSnapshot,
        allowRemovals: Bool
    ) -> CatalogSnapshot {
        guard snapshot.catalogID == diff.baseCatalogID,
              snapshot.updatedAt == diff.baseCatalogUpdatedAt else { return snapshot }
        var items = snapshot.items.map(Optional.some)
        var indicesByID: [UUID: [Int]] = [:]
        var pathCounts: [String: Int] = [:]
        for (index, item) in snapshot.items.enumerated() {
            indicesByID[item.id, default: []].append(index)
            pathCounts[item.source.relativePath, default: 0] += 1
        }

        func firstIndex(id: UUID) -> Int? {
            indicesByID[id]?.first { items[$0] != nil }
        }

        func matchingIndex(id: UUID, expected: SourceRevision) -> Int? {
            indicesByID[id]?.first { index in
                guard let item = items[index] else { return false }
                return item.source.relativePath == expected.relativePath &&
                    item.source.portableFingerprint == expected.portableFingerprint &&
                    item.source.fileModificationDate == expected.fileModificationDate
            }
        }

        func decrementPath(_ path: String) {
            guard let count = pathCounts[path] else { return }
            if count == 1 {
                pathCounts[path] = nil
            } else {
                pathCounts[path] = count - 1
            }
        }

        for operation in diff.operations {
            switch operation {
            case .addRecord(let record):
                let path = record.item.source.relativePath
                guard pathCounts[path] == nil else { continue }
                let index = items.count
                items.append(record.item)
                indicesByID[record.item.id, default: []].append(index)
                pathCounts[path] = 1
            case .updateSource(let id, let expected, let newValue):
                guard let index = matchingIndex(id: id, expected: expected),
                      var item = items[index] else { continue }
                decrementPath(item.source.relativePath)
                pathCounts[newValue.relativePath, default: 0] += 1
                item.source = newValue
                item.availability = .available
                items[index] = item
            case .updatePath(let id, let expected, let newPath, let newTitle):
                guard let index = matchingIndex(id: id, expected: expected),
                      var item = items[index] else { continue }
                decrementPath(item.source.relativePath)
                pathCounts[newPath, default: 0] += 1
                item.source.relativePath = newPath
                item.source.filename = (newPath as NSString).lastPathComponent
                item.source.sourceTitle = newTitle
                items[index] = item
            case .updateFinderComment(let id, let expected, let comment):
                guard let index = matchingIndex(id: id, expected: expected),
                      var item = items[index] else { continue }
                item.source.finderComment = comment
                items[index] = item
            case .markMissing(let id, let expected):
                guard let index = matchingIndex(id: id, expected: expected),
                      var item = items[index] else { continue }
                item.availability = .temporarilyUnavailable
                items[index] = item
            case .markAvailable(let id, let expected):
                guard let index = matchingIndex(id: id, expected: expected),
                      var item = items[index] else { continue }
                item.availability = .available
                items[index] = item
            case .markAmbiguous(let id, let candidates):
                if let index = firstIndex(id: id), var item = items[index] {
                    item.availability = .ambiguousMatch
                    items[index] = item
                    ambiguousCandidates[id] = candidates
                }
            case .removeRecord(let id, let expected):
                guard allowRemovals else { continue }
                guard let index = matchingIndex(id: id, expected: expected),
                      let item = items[index] else { continue }
                decrementPath(item.source.relativePath)
                items[index] = nil
            }
        }
        var result = snapshot
        result.items = items.compactMap { $0 }
        return result
    }

    private func registerUndo(previous: CatalogItem, actionName: String) {
        guard let undoManager = undoManagerProvider() else { return }
        registerUndo(previous: previous, actionName: actionName, using: undoManager)
    }

    private func registerUndo(
        previous: CatalogItem,
        actionName: String,
        using undoManager: UndoManager
    ) {
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

    private func registerCatalogUndo(previous: CatalogSnapshot, actionName: String) {
        guard let undoManager = NSApp.keyWindow?.undoManager ?? NSApp.mainWindow?.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { store in
            Task { await store.restoreCatalogSnapshotForUndo(previous, actionName: actionName) }
        }
        undoManager.setActionName(actionName)
    }

    private func restoreCatalogSnapshotForUndo(_ requested: CatalogSnapshot, actionName: String) async {
        guard let current = catalog, let catalogURL, !current.isReadOnly else { return }
        var restored = requested
        restored.updatedAt = .now
        do {
            saveState = .saving
            try await saveCoordinator.save(restored, to: catalogURL, reason: .conflictResolution)
            catalog = restored
            if let selection, !restored.items.contains(where: { $0.id == selection }) {
                self.selection = restored.items.first?.id
            }
            saveState = .saved(.now)
            registerCatalogUndo(previous: current, actionName: actionName)
        } catch {
            await handleSaveFailure(error)
        }
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

    private func persistAccess(
        catalogURL: URL,
        coverFolderURL: URL?,
        snapshot: CatalogSnapshot,
        preserveExistingCoverAccess: Bool = false
    ) async throws {
        do {
            try await bookmarkStore.save(
                catalogURL: catalogURL,
                coverFolderURL: coverFolderURL,
                snapshot: snapshot,
                preserveExistingCoverAccess: preserveExistingCoverAccess
            )
            VitrineLog.access.info("Persisted catalog access")
        } catch {
            VitrineLog.access.error("Failed to persist catalog access")
            throw CatalogError.accessPersistenceFailed
        }
    }

    @discardableResult
    private func handleSaveFailure(
        _ error: Error,
        localCandidate: CatalogSnapshot? = nil
    ) async -> Bool {
        if let catalogError = error as? CatalogError {
            switch catalogError {
            case .externalConflict:
                presentedError = nil
                saveState = .failed(error.localizedDescription)
                let recovered = await processCatalogFileEvent(
                    .changed,
                    localCandidate: localCandidate
                )
                if recovered {
                    saveState = .saved(.now)
                }
                return recovered
            default:
                presentedError = .coordinatedWriteFailed
            }
        } else {
            presentedError = .coordinatedWriteFailed
        }
        saveState = .failed(error.localizedDescription)
        return false
    }

    private func performCatalogOperation(
        message: String?,
        failure fallbackError: CatalogError,
        operation: () async throws -> Void
    ) async {
        let presentsActivity = message != nil
        if presentsActivity {
            isPerformingCatalogOperation = true
            operationMessage = message
        } else {
            isPerformingBackgroundCatalogOperation = true
        }
        if presentsActivity { presentedError = nil }
        var externalConflictOccurred = false
        do { try await operation() }
        catch is CancellationError {
            scanState = .idle
            statusMessage = L10n.text("Refresh cancelled")
        } catch let error as CatalogError {
            if case .externalConflict = error {
                externalConflictOccurred = true
            } else if presentsActivity {
                presentedError = error
            } else {
                VitrineLog.catalog.error("Background catalog operation failed and will be retried later")
            }
            saveState = .failed(error.localizedDescription)
        } catch {
            if presentsActivity {
                presentedError = fallbackError
            } else {
                VitrineLog.catalog.error("Background catalog operation failed and will be retried later")
            }
            saveState = .failed(error.localizedDescription)
        }
        if presentsActivity {
            isPerformingCatalogOperation = false
            operationMessage = nil
        } else {
            isPerformingBackgroundCatalogOperation = false
        }
        resumeCatalogFileEventWaiters()
        if externalConflictOccurred {
            await processCatalogFileEvent(.changed)
        }
    }

    private var catalogOperationIsActive: Bool {
        isPerformingCatalogOperation || isPerformingBackgroundCatalogOperation
    }

    nonisolated static func refreshRequiresSave(
        current: CatalogSnapshot,
        proposed: CatalogSnapshot
    ) -> Bool {
        proposed.items != current.items ||
            proposed.sourceFolderName != current.sourceFolderName ||
            proposed.sourceFolderSignature != current.sourceFolderSignature
    }

    private func matchesFilter(_ item: CatalogItem) -> Bool {
        switch filter {
        case .all: true
        case .coversAvailable: item.availability == .available
        case .coverNotFound: item.availability != .available
        case .needsReview: needsFilenameReview(item)
        case .missingISBN: item.bibliography.isbn10 == nil && item.bibliography.isbn13 == nil
        case .hasISBN: item.bibliography.isbn10 != nil || item.bibliography.isbn13 != nil
        case .detailsAdded: item.bibliography.title != nil
        case .noDetails: item.bibliography.title == nil
        }
    }

    private func needsFilenameReview(_ item: CatalogItem) -> Bool {
        switch item.bibliography.metadataSource {
        case .filename, .mixed:
            false
        case .manual, .openLibrary, nil:
            true
        }
    }

    private func areInIncreasingOrder(_ lhs: CatalogItem, _ rhs: CatalogItem) -> Bool {
        guard let left = derivedIndex.entry(for: lhs.id),
              let right = derivedIndex.entry(for: rhs.id) else { return false }
        switch sortOption {
        case .titleAscending:
            guard let leftTitle = left.title, let rightTitle = right.title else { return false }
            return leftTitle < rightTitle
        case .titleDescending:
            guard let leftTitle = left.title, let rightTitle = right.title else { return false }
            return leftTitle > rightTitle
        case .author:
            guard let leftAuthor = left.author, let rightAuthor = right.author else { return false }
            return leftAuthor < rightAuthor
        case .filename:
            return lhs.source.filename.localizedStandardCompare(rhs.source.filename) == .orderedAscending
        case .publisher:
            guard let leftPublisher = left.publisher, let rightPublisher = right.publisher else { return false }
            return leftPublisher < rightPublisher
        case .collection:
            guard let leftCollection = left.collection, let rightCollection = right.collection else { return false }
            return leftCollection < rightCollection
        case .dateAdded:
            return lhs.dateAdded < rhs.dateAdded
        case .coverFileModified:
            return (lhs.source.fileModificationDate ?? .distantPast) <
                (rhs.source.fileModificationDate ?? .distantPast)
        case .recentlyUpdated:
            return lhs.dateModified > rhs.dateModified
        }
    }

}

private struct DeferredItemUndo {
    let previous: CatalogItem
    let actionName: String
}
