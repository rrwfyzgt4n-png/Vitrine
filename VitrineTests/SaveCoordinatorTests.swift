import XCTest
@testable import Vitrine

final class SaveCoordinatorTests: XCTestCase {
    func testUnsupportedSchemaCatalogCannotBeSaved() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let snapshot = CatalogSnapshot(
            schemaVersion: CatalogSnapshot.supportedSchemaVersion + 1,
            name: "Future Catalog",
            isReadOnly: true
        )

        do {
            try await CatalogSaveCoordinator(editDebounce: .zero).save(snapshot, to: url)
            XCTFail("Expected a read-only future catalog to reject the save")
        } catch let error as CatalogError {
            guard case .unsupportedSchema = error else {
                return XCTFail("Expected unsupportedSchema, got \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testSaveCoordinatorCreatesParseableCatalog() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let date = try XCTUnwrap(CatalogDateFormatter.date(from: "2026-07-18T20:00:00Z"))
        let snapshot = CatalogSnapshot(
            catalogID: UUID(uuidString: "9A50D16E-51E8-4867-B81E-2525F910AD51")!,
            name: "My Library",
            createdAt: date,
            updatedAt: date,
            items: [
                CatalogItem(
                    id: UUID(uuidString: "86CC391A-4662-4553-902D-E8B80D2641DD")!,
                    source: SourceFileMetadata(relativePath: "Kafka/The Trial.jpg"),
                    dateAdded: date,
                    dateModified: date
                )
            ]
        )

        try await CatalogSaveCoordinator().save(snapshot, to: url)
        let parsed = try await CatalogMarkdownStore().read(from: url)

        XCTAssertEqual(parsed.snapshot.catalogID, snapshot.catalogID)
        XCTAssertEqual(parsed.snapshot.items.map(\.source.relativePath), ["Kafka/The Trial.jpg"])
    }

    func testOverlappingMetadataSavesCollapseToNewestSnapshot() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .milliseconds(80))
        var first = CatalogSnapshot(name: "First")
        first.updatedAt = Date(timeIntervalSince1970: 1)
        let newest: CatalogSnapshot = {
            var value = first
            value.name = "Newest"
            value.updatedAt = Date(timeIntervalSince1970: 2)
            return value
        }()

        let firstSave = Task { try await coordinator.save(first, to: url, reason: .metadataEdit) }
        try await Task.sleep(for: .milliseconds(10))
        let newestSave = Task { try await coordinator.save(newest, to: url, reason: .metadataEdit) }
        _ = try await firstSave.value
        _ = try await newestSave.value

        let parsed = try await CatalogMarkdownStore().read(from: url)
        XCTAssertEqual(parsed.snapshot.name, "Newest")
    }

    func testFlushSkipsDebounceAndPersistsQueuedSave() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .seconds(30))
        let snapshot = CatalogSnapshot(name: "Flush Me")

        let save = Task { try await coordinator.save(snapshot, to: url, reason: .metadataEdit) }
        try await waitUntilSaveIsPending(coordinator)
        try await coordinator.flushPendingSaves()
        let persisted = try await save.value

        XCTAssertEqual(persisted, snapshot)
        let reopened = try await CatalogMarkdownStore().read(from: url).snapshot
        XCTAssertEqual(reopened.name, "Flush Me")
    }

    func testFlushCoalescesMetadataEditsToNewestSnapshot() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .seconds(30))
        let first = CatalogSnapshot(name: "First")
        let newest: CatalogSnapshot = {
            var value = first
            value.name = "Newest"
            return value
        }()

        let firstSave = Task { try await coordinator.save(first, to: url, reason: .metadataEdit) }
        try await waitUntilSaveIsPending(coordinator)
        let newestSave = Task { try await coordinator.save(newest, to: url, reason: .metadataEdit) }
        try await Task.sleep(for: .milliseconds(10))
        try await coordinator.flushPendingSaves()

        let firstResult = try await firstSave.value
        let newestResult = try await newestSave.value
        let reopened = try await CatalogMarkdownStore().read(from: url).snapshot
        XCTAssertEqual(firstResult, newest)
        XCTAssertEqual(newestResult, newest)
        XCTAssertEqual(reopened.name, "Newest")
    }

    func testExplicitSaveWakesMetadataDebounceAndPersistsNewestSnapshot() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .seconds(30))
        let first = CatalogSnapshot(name: "Metadata")
        let explicit: CatalogSnapshot = {
            var value = first
            value.name = "Explicit"
            return value
        }()

        let firstSave = Task { try await coordinator.save(first, to: url, reason: .metadataEdit) }
        try await waitUntilSaveIsPending(coordinator)
        let explicitSave = Task { try await coordinator.save(explicit, to: url, reason: .explicit) }

        let firstResult = try await firstSave.value
        let explicitResult = try await explicitSave.value
        let reopened = try await CatalogMarkdownStore().read(from: url).snapshot
        XCTAssertEqual(firstResult, explicit)
        XCTAssertEqual(explicitResult, explicit)
        XCTAssertEqual(reopened.name, "Explicit")
    }

    func testFlushReportsSaveFailure() async throws {
        let expected = CatalogError.coordinatedWriteFailed
        let coordinator = CatalogSaveCoordinator(
            editDebounce: .seconds(30),
            saveOperation: { _, _ in throw expected }
        )
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        let save = Task {
            try await coordinator.save(CatalogSnapshot(name: "Failure"), to: url, reason: .metadataEdit)
        }
        try await waitUntilSaveIsPending(coordinator)

        do {
            try await coordinator.flushPendingSaves()
            XCTFail("Expected the flush to report the write failure")
        } catch let error as CatalogError {
            XCTAssertEqual(error.localizedDescription, expected.localizedDescription)
        }
        do {
            _ = try await save.value
            XCTFail("Expected the queued caller to receive the write failure")
        } catch {}
    }

    func testSaveArrivingDuringInFlightWriteRunsAfterItsPredecessor() async throws {
        let probe = BlockingSaveOperation()
        let coordinator = CatalogSaveCoordinator(
            editDebounce: .zero,
            saveOperation: { snapshot, url in
                try await probe.save(snapshot, to: url)
            }
        )
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        let first = CatalogSnapshot(name: "First")
        let successor = CatalogSnapshot(catalogID: first.catalogID, name: "Successor")

        let firstSave = Task { try await coordinator.save(first, to: url) }
        await probe.waitUntilFirstSaveStarts()
        let successorSave = Task { try await coordinator.save(successor, to: url) }
        await probe.releaseFirstSave()

        let firstReceipt = try await firstSave.value
        let successorReceipt = try await successorSave.value
        let recorded = await probe.recordedSnapshots()
        XCTAssertEqual(firstReceipt.name, "First")
        XCTAssertEqual(successorReceipt.name, "Successor")
        XCTAssertEqual(recorded.map(\.name), ["First", "Successor"])
    }

    @MainActor
    func testFailedEditedItemSaveLeavesCatalogAndUndoUnchanged() async throws {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Book.jpg"))
        let original = CatalogSnapshot(name: "Library", items: [item])
        let coordinator = CatalogSaveCoordinator(
            editDebounce: .zero,
            saveOperation: { _, _ in throw CatalogError.coordinatedWriteFailed }
        )
        let undoManager = UndoManager()
        let store = CatalogStore(
            saveCoordinator: coordinator,
            catalogURL: FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md"),
            undoManagerProvider: { undoManager }
        )
        store.catalog = original
        var edited = item
        edited.bibliography.title = "Unsaved Title"

        let didSave = await store.saveEditedItem(edited)
        XCTAssertFalse(didSave)
        XCTAssertEqual(store.catalog, original)
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testSuccessfulEditedItemSaveCommitsCatalogAndRegistersUndo() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Book.jpg"))
        let original = CatalogSnapshot(name: "Library", items: [item])
        let coordinator = CatalogSaveCoordinator(editDebounce: .zero)
        try await coordinator.save(original, to: url)
        let undoManager = UndoManager()
        let store = CatalogStore(
            saveCoordinator: coordinator,
            catalogURL: url,
            undoManagerProvider: { undoManager }
        )
        store.catalog = original
        var edited = item
        edited.bibliography.title = "Saved Title"

        let didSave = await store.saveEditedItem(edited)
        let reopened = try await CatalogMarkdownStore().read(from: url).snapshot
        XCTAssertTrue(didSave)
        XCTAssertEqual(store.catalog?.items.first?.bibliography.title, "Saved Title")
        XCTAssertEqual(reopened.items.first?.bibliography.title, "Saved Title")
        XCTAssertTrue(undoManager.canUndo)
    }

    @MainActor
    func testConcurrentEditedItemSavesPreserveBothChanges() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let first = CatalogItem(source: SourceFileMetadata(relativePath: "First.jpg"))
        let second = CatalogItem(source: SourceFileMetadata(relativePath: "Second.jpg"))
        let original = CatalogSnapshot(name: "Library", items: [first, second])
        let coordinator = CatalogSaveCoordinator(editDebounce: .milliseconds(80))
        try await coordinator.save(original, to: url)
        let store = CatalogStore(saveCoordinator: coordinator, catalogURL: url, undoManagerProvider: { nil })
        store.catalog = original
        var editedFirst = first
        editedFirst.bibliography.title = "First Title"
        var editedSecond = second
        editedSecond.bibliography.title = "Second Title"

        async let firstResult = store.saveEditedItem(editedFirst)
        try await Task.sleep(for: .milliseconds(10))
        async let secondResult = store.saveEditedItem(editedSecond)
        let didSaveFirst = await firstResult
        let didSaveSecond = await secondResult
        XCTAssertTrue(didSaveFirst)
        XCTAssertTrue(didSaveSecond)

        let persisted = try await CatalogMarkdownStore().read(from: url).snapshot
        XCTAssertEqual(persisted.items[0].bibliography.title, "First Title")
        XCTAssertEqual(persisted.items[1].bibliography.title, "Second Title")
        XCTAssertEqual(store.catalog?.items[0].bibliography.title, "First Title")
        XCTAssertEqual(store.catalog?.items[1].bibliography.title, "Second Title")
    }

    func testConsecutiveBookDetailSavesKeepBothAcceptedSuggestions() async throws {
        let catalogID = UUID()
        let firstID = UUID()
        let secondID = UUID()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(catalogID.uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .milliseconds(80))
        let base = CatalogSnapshot(
            catalogID: catalogID,
            name: "Library",
            items: [
                CatalogItem(id: firstID, source: SourceFileMetadata(relativePath: "First.jpg")),
                CatalogItem(id: secondID, source: SourceFileMetadata(relativePath: "Second.jpg")),
            ]
        )
        try await coordinator.save(base, to: url)

        var firstAccepted = base
        firstAccepted.items[0].bibliography.title = "First Parsed Title"
        var secondAccepted = firstAccepted
        secondAccepted.items[1].bibliography.title = "Second Parsed Title"
        let firstSave = Task {
            try await coordinator.save(firstAccepted, to: url, reason: .metadataEdit)
        }
        try await Task.sleep(for: .milliseconds(10))
        let secondSave = Task {
            try await coordinator.save(secondAccepted, to: url, reason: .metadataEdit)
        }
        _ = try await firstSave.value
        _ = try await secondSave.value

        let parsed = try await CatalogMarkdownStore().read(from: url).snapshot
        let items = Dictionary(uniqueKeysWithValues: parsed.items.map { ($0.id, $0) })
        XCTAssertEqual(items[firstID]?.bibliography.title, "First Parsed Title")
        XCTAssertEqual(items[secondID]?.bibliography.title, "Second Parsed Title")
        let backups = try await coordinator.backups(catalogID: catalogID)
        if let folder = backups.first?.url.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    func testExternalDiskChangeIsNotOverwritten() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .zero)
        var baseline = CatalogSnapshot(name: "Baseline")
        try await coordinator.save(baseline, to: url)

        var external = baseline
        external.name = "External"
        external.updatedAt = Date(timeIntervalSince1970: 2)
        let externalData = try XCTUnwrap(try CatalogMarkdownWriter().render(external).data(using: .utf8))
        try externalData.write(to: url, options: .atomic)

        baseline.name = "Local"
        baseline.updatedAt = Date(timeIntervalSince1970: 3)
        do {
            try await coordinator.save(baseline, to: url)
            XCTFail("Expected the changed disk baseline to block the save")
        } catch let error as CatalogError {
            guard case .externalConflict = error else {
                return XCTFail("Expected externalConflict, got \(error)")
            }
        }

        let parsed = try await CatalogMarkdownStore().read(from: url)
        XCTAssertEqual(parsed.snapshot.name, "External")
    }

    func testRestoreRefreshesBaselineForTheNextSave() async throws {
        let id = UUID()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(id.uuidString).md")
        defer { try? FileManager.default.removeItem(at: url) }
        let coordinator = CatalogSaveCoordinator(editDebounce: .zero)
        let original = CatalogSnapshot(catalogID: id, name: "Original")
        var changed = original
        changed.name = "Changed"
        try await coordinator.save(original, to: url)
        try await coordinator.save(changed, to: url)
        let backups = try await coordinator.backups(catalogID: id)
        let backup = try XCTUnwrap(backups.first)
        defer { try? FileManager.default.removeItem(at: backup.url.deletingLastPathComponent()) }

        let restored = try await coordinator.restore(backup, to: url, catalogID: id)
        var editedAfterRestore = restored
        editedAfterRestore.name = "Edited After Restore"
        try await coordinator.save(editedAfterRestore, to: url)

        let parsed = try await CatalogMarkdownStore().read(from: url)
        XCTAssertEqual(parsed.snapshot.name, "Edited After Restore")
    }

    private func waitUntilSaveIsPending(_ coordinator: CatalogSaveCoordinator) async throws {
        for _ in 0..<100 {
            if await coordinator.hasPendingSaveWork() { return }
            try await Task.sleep(for: .milliseconds(2))
        }
        XCTFail("Save was never enqueued")
    }
}

private actor BlockingSaveOperation {
    private var snapshots: [CatalogSnapshot] = []
    private var firstSaveStarted = false
    private var releaseWasRequested = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func save(_ snapshot: CatalogSnapshot, to url: URL) async throws {
        snapshots.append(snapshot)
        guard snapshots.count == 1 else { return }
        firstSaveStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
        guard !releaseWasRequested else { return }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitUntilFirstSaveStarts() async {
        guard !firstSaveStarted else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseFirstSave() {
        releaseWasRequested = true
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func recordedSnapshots() -> [CatalogSnapshot] {
        snapshots
    }
}
