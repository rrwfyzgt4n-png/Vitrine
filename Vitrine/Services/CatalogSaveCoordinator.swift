import Foundation
import CryptoKit

actor CatalogSaveCoordinator {
    typealias SaveOperation = @Sendable (CatalogSnapshot, URL) async throws -> Void

    private let writer = CatalogMarkdownWriter()
    private let backupService = CatalogBackupService()
    private var baselines: [URL: CatalogDiskBaseline] = [:]
    private var saveQueue: [SaveRequest] = []
    private var isProcessingSaveQueue = false
    private var processingTask: Task<Void, Never>?
    private var flushWaiters: [CheckedContinuation<Void, any Error>] = []
    private var flushFailure: (any Error)?
    private var isFlushRequested = false
    private let editDebounce: Duration
    private let saveOperation: SaveOperation?

    init(
        editDebounce: Duration = .seconds(1.5),
        saveOperation: SaveOperation? = nil
    ) {
        self.editDebounce = editDebounce
        self.saveOperation = saveOperation
    }

    @discardableResult
    func save(
        _ snapshot: CatalogSnapshot,
        to url: URL,
        reason: CatalogSaveReason = .explicit
    ) async throws -> CatalogSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            let key = url.standardizedFileURL
            if let index = saveQueue.firstIndex(where: { $0.url == key }) {
                saveQueue[index].snapshot = snapshot
                saveQueue[index].reasons.insert(reason)
                saveQueue[index].requestedAt = .now
                saveQueue[index].continuations.append(continuation)
            } else {
                saveQueue.append(SaveRequest(
                    snapshot: snapshot,
                    url: key,
                    reasons: [reason],
                    requestedAt: .now,
                    continuations: [continuation]
                ))
            }
            if reason != .metadataEdit {
                processingTask?.cancel()
            }
            if !isProcessingSaveQueue {
                startProcessingSaveQueue()
            }
        }
    }

    func flushPendingSaves() async throws {
        guard isProcessingSaveQueue || !saveQueue.isEmpty else { return }
        try await withCheckedThrowingContinuation { continuation in
            flushWaiters.append(continuation)
            isFlushRequested = true
            processingTask?.cancel()
            if !isProcessingSaveQueue {
                startProcessingSaveQueue()
            }
        }
    }

    func hasPendingSaveWork() -> Bool {
        isProcessingSaveQueue || !saveQueue.isEmpty
    }

    private func startProcessingSaveQueue() {
        isProcessingSaveQueue = true
        processingTask = Task { await self.processSaveQueue() }
    }

    private func processSaveQueue() async {
        while !saveQueue.isEmpty {
            if saveQueue[0].reasons == [.metadataEdit], !isFlushRequested {
                try? await Task.sleep(for: editDebounce)
            }
            let request = saveQueue.removeFirst()
            do {
                if let saveOperation {
                    try await saveOperation(request.snapshot, request.url)
                } else {
                    try await performSave(request.snapshot, to: request.url)
                }
                request.continuations.forEach { $0.resume(returning: request.snapshot) }
            } catch {
                if isFlushRequested, flushFailure == nil {
                    flushFailure = error
                }
                request.continuations.forEach { $0.resume(throwing: error) }
            }
        }
        isProcessingSaveQueue = false
        processingTask = nil
        finishFlushIfNeeded()
    }

    private func finishFlushIfNeeded() {
        guard !flushWaiters.isEmpty else {
            isFlushRequested = false
            flushFailure = nil
            return
        }
        let waiters = flushWaiters
        let failure = flushFailure
        flushWaiters.removeAll(keepingCapacity: true)
        flushFailure = nil
        isFlushRequested = false
        if let failure {
            waiters.forEach { $0.resume(throwing: failure) }
        } else {
            waiters.forEach { $0.resume() }
        }
    }

    private func performSave(_ snapshot: CatalogSnapshot, to url: URL) async throws {
        guard !snapshot.isReadOnly else {
            throw CatalogError.unsupportedSchema(snapshot.schemaVersion)
        }
        let markdown = try writer.render(snapshot)
        guard let data = markdown.data(using: .utf8) else {
            throw CatalogError.coordinatedWriteFailed
        }

        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        let expectedDiskDigest = baselines[url.standardizedFileURL]?.contentDigest
        let diskState = try await Task.detached(priority: .userInitiated) {
            try Self.coordinatedDiskState(at: url)
        }.value
        guard diskState.unresolvedConflictVersions == 0 else {
            throw CatalogError.externalConflict
        }
        if let expectedDiskDigest {
            guard diskState.contentDigest == expectedDiskDigest else {
                throw CatalogError.externalConflict
            }
        }
        if let previousData = diskState.data {
            try await backupService.preserve(previousData, catalogID: snapshot.catalogID)
        }
        try await Task.detached(priority: .userInitiated) {
            try Self.coordinatedReplace(
                data,
                at: url,
                expectedContentDigest: diskState.contentDigest
            )
        }.value
        let writtenData = try await Task.detached(priority: .userInitiated) {
            try Self.coordinatedReadData(from: url)
        }.value
        guard Self.digest(writtenData) == Self.digest(data) else {
            throw CatalogError.coordinatedWriteFailed
        }
        let values = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey, .contentModificationDateKey])
        baselines[url.standardizedFileURL] = CatalogDiskBaseline(
            fileResourceIdentifier: values?.fileResourceIdentifier as? Data,
            modificationDate: values?.contentModificationDate,
            contentDigest: Self.digest(writtenData),
            parsedCatalog: snapshot
        )
    }

    func baseline(for url: URL) -> CatalogDiskBaseline? {
        baselines[url.standardizedFileURL]
    }

    func establishBaseline(
        _ snapshot: CatalogSnapshot,
        at url: URL,
        expectedContentDigest: String? = nil
    ) async throws {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        let data = try await Task.detached(priority: .userInitiated) {
            try Self.coordinatedReadData(from: url)
        }.value
        let contentDigest = Self.digest(data)
        if let expectedContentDigest, contentDigest != expectedContentDigest {
            throw CatalogError.externalConflict
        }
        let values = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey, .contentModificationDateKey])
        baselines[url.standardizedFileURL] = CatalogDiskBaseline(
            fileResourceIdentifier: values?.fileResourceIdentifier as? Data,
            modificationDate: values?.contentModificationDate,
            contentDigest: contentDigest,
            parsedCatalog: snapshot
        )
    }

    private nonisolated static func coordinatedReadData(from url: URL) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            result = Result { try Data(contentsOf: coordinatedURL, options: [.mappedIfSafe]) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CatalogError.coordinatedReadFailed }
        return try result.get()
    }

    private nonisolated static func coordinatedDiskState(at url: URL) throws -> CoordinatedDiskState {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return CoordinatedDiskState(data: nil, contentDigest: nil, unresolvedConflictVersions: 0)
        }
        let data = try coordinatedReadData(from: url)
        return CoordinatedDiskState(
            data: data,
            contentDigest: digest(data),
            unresolvedConflictVersions: NSFileVersion.unresolvedConflictVersionsOfItem(at: url)?.count ?? 0
        )
    }

    private nonisolated static func coordinatedReplace(
        _ data: Data,
        at url: URL,
        expectedContentDigest: String?
    ) throws {
        var coordinationError: NSError?
        var writeError: Error?
        let coordinator = NSFileCoordinator(filePresenter: nil)
        let options: NSFileCoordinator.WritingOptions = expectedContentDigest == nil ? [] : .forReplacing
        coordinator.coordinate(writingItemAt: url, options: options, error: &coordinationError) { coordinatedURL in
            do {
                let exists = FileManager.default.fileExists(atPath: coordinatedURL.path)
                guard NSFileVersion.unresolvedConflictVersionsOfItem(at: coordinatedURL)?.isEmpty != false else {
                    throw CatalogError.externalConflict
                }
                if let expectedContentDigest {
                    guard exists else { throw CatalogError.externalConflict }
                    let currentData = try Data(contentsOf: coordinatedURL, options: [.mappedIfSafe])
                    guard digest(currentData) == expectedContentDigest else {
                        throw CatalogError.externalConflict
                    }
                } else if exists {
                    throw CatalogError.externalConflict
                }

                // Foundation performs the sibling temporary-file replacement here. Calling
                // FileManager.replaceItemAt directly makes NSFilePresenter report the catalog
                // as deleted to other Vitrine processes during an otherwise normal save.
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let writeError { throw writeError }
        if let coordinationError { throw coordinationError }
    }

    private nonisolated static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func backups(catalogID: UUID) async throws -> [CatalogBackupService.Backup] {
        try await backupService.backups(catalogID: catalogID)
    }

    @discardableResult
    func restore(
        _ backup: CatalogBackupService.Backup,
        to url: URL,
        catalogID: UUID,
        preservingDamagedCurrentCatalog: Bool = false
    ) async throws -> CatalogSnapshot {
        let backupData = try Data(contentsOf: backup.url, options: [.mappedIfSafe])
        guard let source = String(data: backupData, encoding: .utf8) else {
            throw CatalogError.catalogMalformed
        }
        let snapshot = try CatalogMarkdownParser().parse(source).snapshot
        guard snapshot.catalogID == catalogID, !snapshot.isReadOnly else {
            throw CatalogError.catalogMalformed
        }

        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        let diskState = try await Task.detached(priority: .userInitiated) {
            try Self.coordinatedDiskState(at: url)
        }.value
        guard diskState.unresolvedConflictVersions == 0 else {
            throw CatalogError.externalConflict
        }
        if let damagedOrCurrentData = diskState.data {
            if preservingDamagedCurrentCatalog {
                _ = try await backupService.preserveDamaged(damagedOrCurrentData, catalogID: catalogID)
            } else {
                try await backupService.preserve(damagedOrCurrentData, catalogID: catalogID)
            }
        }
        try await Task.detached(priority: .userInitiated) {
            try Self.coordinatedReplace(
                backupData,
                at: url,
                expectedContentDigest: diskState.contentDigest
            )
        }.value
        try await establishBaseline(snapshot, at: url)
        return snapshot
    }
}

private struct CoordinatedDiskState: Sendable {
    var data: Data?
    var contentDigest: String?
    var unresolvedConflictVersions: Int
}

private struct SaveRequest {
    var snapshot: CatalogSnapshot
    var url: URL
    var reasons: Set<CatalogSaveReason>
    var requestedAt: Date
    var continuations: [CheckedContinuation<CatalogSnapshot, any Error>]
}
