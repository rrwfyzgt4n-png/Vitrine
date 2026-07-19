import Foundation

actor SecurityScopedBookmarkStore {
    static let shared = SecurityScopedBookmarkStore()

    struct ResolvedAccess: Sendable {
        var catalogID: UUID
        var catalogURL: URL
        var coverFolderURL: URL?
        var sourceFolderSignature: String?
    }

    private let fileManager = FileManager.default
    private let storageURLOverride: URL?

    init(storageURL: URL? = nil) {
        storageURLOverride = storageURL
    }

    func save(catalogURL: URL, coverFolderURL: URL?, snapshot: CatalogSnapshot) throws {
        var accessFile = try loadFile()
        let catalogBookmark = try catalogURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let folderBookmark = try coverFolderURL?.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let volumeValues = try? coverFolderURL?.resourceValues(forKeys: [
            .volumeUUIDStringKey,
            .volumeNameKey,
            .volumeURLKey,
        ])
        let volumeURL = volumeValues?.volume
        let volumeResourceIdentifier = try? volumeURL?.resourceValues(forKeys: [.fileResourceIdentifierKey])
        let relativeFolderPath: String?
        if let folderURL = coverFolderURL,
           let volumeURL = volumeValues?.volume {
            relativeFolderPath = folderURL.pathComponents
                .dropFirst(volumeURL.pathComponents.count)
                .joined(separator: "/")
        } else {
            relativeFolderPath = nil
        }
        accessFile.records[snapshot.catalogID] = CatalogAccessRecord(
            catalogID: snapshot.catalogID,
            catalogBookmark: catalogBookmark,
            coverFolderBookmark: folderBookmark,
            volumeUUID: volumeValues?.volumeUUIDString,
            volumeName: volumeValues?.volumeName,
            relativeFolderPath: relativeFolderPath,
            sourceFolderSignature: snapshot.sourceFolderSignature,
            volumeIdentity: VolumeIdentity(
                uuid: volumeValues?.volumeUUIDString,
                resourceIdentifier: volumeResourceIdentifier?.fileResourceIdentifier.map { String(describing: $0) },
                displayName: volumeValues?.volumeName,
                lastKnownURL: volumeURL,
                relativeFolderPath: relativeFolderPath
            ),
            updatedAt: .now
        )
        accessFile.lastCatalogID = snapshot.catalogID
        try write(accessFile)
    }

    func resolveLast() throws -> ResolvedAccess? {
        var accessFile = try loadFile()
        guard let id = accessFile.lastCatalogID, let record = accessFile.records[id] else { return nil }
        let resolution = try resolve(record)
        if resolution.record != record {
            accessFile.records[id] = resolution.record
            try write(accessFile)
        }
        return resolution.access
    }

    func resolve(catalogID: UUID) throws -> ResolvedAccess? {
        var accessFile = try loadFile()
        guard let record = accessFile.records[catalogID] else { return nil }
        let resolution = try resolve(record)
        if resolution.record != record {
            accessFile.records[catalogID] = resolution.record
            try write(accessFile)
        }
        return resolution.access
    }

    func reconnectMountedVolume(catalogID: UUID) throws -> URL? {
        var accessFile = try loadFile()
        guard var record = accessFile.records[catalogID] else { return nil }
        let identity = record.volumeIdentity ?? VolumeIdentity(
            uuid: record.volumeUUID,
            resourceIdentifier: nil,
            displayName: record.volumeName,
            lastKnownURL: nil,
            relativeFolderPath: record.relativeFolderPath
        )
        guard let relativePath = identity.relativeFolderPath else { return nil }
        let volumes = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeUUIDStringKey],
            options: [.skipHiddenVolumes]
        ) ?? []
        guard let volumeURL = volumes.first(where: { candidate in
            let values = try? candidate.resourceValues(forKeys: [.volumeUUIDStringKey, .fileResourceIdentifierKey])
            if let expectedUUID = identity.uuid, values?.volumeUUIDString == expectedUUID { return true }
            if let expectedResourceID = identity.resourceIdentifier {
                return values?.fileResourceIdentifier.map { String(describing: $0) } == expectedResourceID
            }
            return false
        }) else { return nil }
        let candidate = volumeURL.appending(path: relativePath, directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: candidate.path) else { return nil }
        record.coverFolderBookmark = try candidate.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let volumeValues = try? volumeURL.resourceValues(forKeys: [.volumeUUIDStringKey, .volumeNameKey, .fileResourceIdentifierKey])
        record.volumeIdentity = VolumeIdentity(
            uuid: volumeValues?.volumeUUIDString,
            resourceIdentifier: volumeValues?.fileResourceIdentifier.map { String(describing: $0) },
            displayName: volumeValues?.volumeName,
            lastKnownURL: volumeURL,
            relativeFolderPath: relativePath
        )
        record.updatedAt = .now
        accessFile.records[catalogID] = record
        try write(accessFile)
        return candidate
    }

    private func resolve(_ original: CatalogAccessRecord) throws -> (access: ResolvedAccess, record: CatalogAccessRecord) {
        var record = original
        var catalogStale = false
        let catalogURL = try URL(
            resolvingBookmarkData: record.catalogBookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &catalogStale
        )
        if catalogStale {
            let lease = SecurityScopeLease(url: catalogURL)
            defer { lease.stop() }
            record.catalogBookmark = try catalogURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            record.updatedAt = .now
        }
        var folderURL: URL?
        if let data = record.coverFolderBookmark {
            var folderStale = false
            folderURL = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &folderStale
            )
            if folderStale, let folderURL {
                let lease = SecurityScopeLease(url: folderURL)
                defer { lease.stop() }
                record.coverFolderBookmark = try folderURL.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                record.updatedAt = .now
            }
        }
        let access = ResolvedAccess(
            catalogID: record.catalogID,
            catalogURL: catalogURL,
            coverFolderURL: folderURL,
            sourceFolderSignature: record.sourceFolderSignature
        )
        return (access, record)
    }

    private func loadFile() throws -> CatalogAccessFile {
        let url = try storageURL()
        guard fileManager.fileExists(atPath: url.path) else { return .empty }
        let data = try Data(contentsOf: url)
        return try PropertyListDecoder().decode(CatalogAccessFile.self, from: data)
    }

    private func write(_ value: CatalogAccessFile) throws {
        let data = try PropertyListEncoder().encode(value)
        try data.write(to: storageURL(), options: .atomic)
    }

    private func storageURL() throws -> URL {
        if let storageURLOverride {
            try fileManager.createDirectory(
                at: storageURLOverride.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return storageURLOverride
        }
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "Vitrine", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appending(path: "CatalogAccess.plist")
    }
}
