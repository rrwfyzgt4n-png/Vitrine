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

    func save(
        catalogURL: URL,
        coverFolderURL: URL?,
        snapshot: CatalogSnapshot,
        preserveExistingCoverAccess: Bool = false
    ) throws {
        var accessFile = try loadFile()
        let existing = accessFile.records[snapshot.catalogID]
        let catalogBookmark = try catalogURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let coverAccess: CoverAccessDetails
        if let coverFolderURL {
            coverAccess = try makeCoverAccessDetails(for: coverFolderURL)
        } else if preserveExistingCoverAccess, let existing {
            coverAccess = CoverAccessDetails(
                bookmark: existing.coverFolderBookmark,
                volumeUUID: existing.volumeUUID,
                volumeName: existing.volumeName,
                relativeFolderPath: existing.relativeFolderPath,
                volumeIdentity: existing.volumeIdentity
            )
        } else {
            coverAccess = .empty
        }
        accessFile.records[snapshot.catalogID] = CatalogAccessRecord(
            catalogID: snapshot.catalogID,
            catalogBookmark: catalogBookmark,
            coverFolderBookmark: coverAccess.bookmark,
            volumeUUID: coverAccess.volumeUUID,
            volumeName: coverAccess.volumeName,
            relativeFolderPath: coverAccess.relativeFolderPath,
            sourceFolderSignature: snapshot.sourceFolderSignature,
            volumeIdentity: coverAccess.volumeIdentity,
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

    func catalogID(matching catalogURL: URL) throws -> UUID? {
        let accessFile = try loadFile()
        let target = catalogURL.resolvingSymlinksInPath().standardizedFileURL
        for record in accessFile.records.values {
            var isStale = false
            guard let rememberedURL = try? URL(
                resolvingBookmarkData: record.catalogBookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }
            if rememberedURL.resolvingSymlinksInPath().standardizedFileURL == target {
                return record.catalogID
            }
        }
        return nil
    }

    func reconnectMountedVolume(catalogID: UUID) throws -> URL? {
        let accessFile = try loadFile()
        guard let record = accessFile.records[catalogID] else { return nil }
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
        let candidates = volumes.map { candidate -> MountedVolumeCandidate in
            let values = try? candidate.resourceValues(forKeys: [.volumeUUIDStringKey, .fileResourceIdentifierKey])
            return MountedVolumeCandidate(
                url: candidate,
                uuid: values?.volumeUUIDString,
                resourceIdentifier: values?.fileResourceIdentifier.map { String(describing: $0) }
            )
        }
        guard let volumeURL = VolumeReconnectMatcher().matchingVolume(
            for: identity,
            candidates: candidates
        ) else { return nil }
        let candidate = volumeURL.appending(path: relativePath, directoryHint: .isDirectory)
        return isReachableDirectory(candidate) ? candidate : nil
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
            if let candidate = try? URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    relativeTo: nil,
                    bookmarkDataIsStale: &folderStale
                ), isReachableDirectory(candidate) {
                folderURL = candidate
                if folderStale {
                    let lease = SecurityScopeLease(url: candidate)
                    defer { lease.stop() }
                    record.coverFolderBookmark = try candidate.bookmarkData(
                        options: [.withSecurityScope],
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    record.updatedAt = .now
                }
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

    private func makeCoverAccessDetails(for folderURL: URL) throws -> CoverAccessDetails {
        let bookmark = try folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let volumeValues = try? folderURL.resourceValues(forKeys: [
            .volumeUUIDStringKey,
            .volumeNameKey,
            .volumeURLKey,
        ])
        let volumeURL = volumeValues?.volume
        let volumeResourceIdentifier = try? volumeURL?.resourceValues(forKeys: [.fileResourceIdentifierKey])
        let relativeFolderPath: String?
        if let volumeURL,
           folderURL.pathComponents.starts(with: volumeURL.pathComponents) {
            relativeFolderPath = folderURL.pathComponents
                .dropFirst(volumeURL.pathComponents.count)
                .joined(separator: "/")
        } else {
            relativeFolderPath = nil
        }
        return CoverAccessDetails(
            bookmark: bookmark,
            volumeUUID: volumeValues?.volumeUUIDString,
            volumeName: volumeValues?.volumeName,
            relativeFolderPath: relativeFolderPath,
            volumeIdentity: VolumeIdentity(
                uuid: volumeValues?.volumeUUIDString,
                resourceIdentifier: volumeResourceIdentifier?.fileResourceIdentifier.map { String(describing: $0) },
                displayName: volumeValues?.volumeName,
                lastKnownURL: volumeURL,
                relativeFolderPath: relativeFolderPath
            )
        )
    }

    private func isReachableDirectory(_ url: URL) -> Bool {
        let lease = SecurityScopeLease(url: url)
        defer { lease.stop() }
        guard (try? url.checkResourceIsReachable()) == true else { return false }
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
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

private struct CoverAccessDetails {
    var bookmark: Data?
    var volumeUUID: String?
    var volumeName: String?
    var relativeFolderPath: String?
    var volumeIdentity: VolumeIdentity?

    static let empty = CoverAccessDetails(
        bookmark: nil,
        volumeUUID: nil,
        volumeName: nil,
        relativeFolderPath: nil,
        volumeIdentity: nil
    )
}
