import Foundation
import CryptoKit

actor CatalogSaveCoordinator {
    private let writer = CatalogMarkdownWriter()
    private let backupService = CatalogBackupService()
    private var baselines: [URL: CatalogDiskBaseline] = [:]
    private var saveQueue: [SaveRequest] = []
    private var isProcessingSaveQueue = false
    private let editDebounce: Duration

    init(editDebounce: Duration = .seconds(1.5)) {
        self.editDebounce = editDebounce
    }

    func save(
        _ snapshot: CatalogSnapshot,
        to url: URL,
        reason: CatalogSaveReason = .explicit
    ) async throws {
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
            if !isProcessingSaveQueue {
                isProcessingSaveQueue = true
                Task { await self.processSaveQueue() }
            }
        }
    }

    private func processSaveQueue() async {
        while !saveQueue.isEmpty {
            if saveQueue[0].reasons.contains(.metadataEdit) {
                try? await Task.sleep(for: editDebounce)
            }
            let request = saveQueue.removeFirst()
            do {
                try await performSave(request.snapshot, to: request.url)
                request.continuations.forEach { $0.resume() }
            } catch {
                request.continuations.forEach { $0.resume(throwing: error) }
            }
        }
        isProcessingSaveQueue = false
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
        try await backupService.preserveCurrentCatalog(at: url, catalogID: snapshot.catalogID)

        try await Task.detached(priority: .userInitiated) {
            var coordinationError: NSError?
            var writeError: Error?
            let coordinator = NSFileCoordinator(filePresenter: nil)
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
                do {
                    try data.write(to: coordinatedURL, options: .atomic)
                } catch {
                    writeError = error
                }
            }

            if coordinationError != nil || writeError != nil {
                throw writeError ?? coordinationError ?? CatalogError.coordinatedWriteFailed
            }
        }.value
        let values = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey, .contentModificationDateKey])
        baselines[url.standardizedFileURL] = CatalogDiskBaseline(
            fileResourceIdentifier: values?.fileResourceIdentifier as? Data,
            modificationDate: values?.contentModificationDate,
            contentDigest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            parsedCatalog: snapshot
        )
    }

    func baseline(for url: URL) -> CatalogDiskBaseline? {
        baselines[url.standardizedFileURL]
    }

    func establishBaseline(_ snapshot: CatalogSnapshot, at url: URL) throws {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let values = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey, .contentModificationDateKey])
        baselines[url.standardizedFileURL] = CatalogDiskBaseline(
            fileResourceIdentifier: values?.fileResourceIdentifier as? Data,
            modificationDate: values?.contentModificationDate,
            contentDigest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            parsedCatalog: snapshot
        )
    }

    func backups(catalogID: UUID) async throws -> [CatalogBackupService.Backup] {
        try await backupService.backups(catalogID: catalogID)
    }

    func restore(_ backup: CatalogBackupService.Backup, to url: URL, catalogID: UUID) async throws {
        try await backupService.preserveCurrentCatalog(at: url, catalogID: catalogID)
        try await backupService.restore(backup, to: url)
    }
}

private struct SaveRequest {
    var snapshot: CatalogSnapshot
    var url: URL
    var reasons: Set<CatalogSaveReason>
    var requestedAt: Date
    var continuations: [CheckedContinuation<Void, any Error>]
}
