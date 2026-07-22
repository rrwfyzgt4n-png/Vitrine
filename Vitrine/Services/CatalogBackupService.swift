import Foundation

actor CatalogBackupService {
    struct Backup: Identifiable, Equatable, Sendable {
        var id: URL { url }
        var url: URL
        var date: Date
    }

    private let fileManager = FileManager.default
    private let retentionCount = 10

    func preserveCurrentCatalog(at catalogURL: URL, catalogID: UUID) throws {
        guard fileManager.fileExists(atPath: catalogURL.path) else { return }
        let data = try Data(contentsOf: catalogURL, options: [.mappedIfSafe])
        try preserve(data, catalogID: catalogID)
    }

    func preserve(_ data: Data, catalogID: UUID) throws {
        guard !data.isEmpty else { return }
        let folder = try backupFolder(catalogID: catalogID)
        let stamp = String(Int(Date.now.timeIntervalSince1970 * 1_000))
        try data.write(to: folder.appending(path: "Catalog-\(stamp)-\(UUID().uuidString).md"), options: .atomic)
        try rotate(folder: folder)
    }

    func preserveDamaged(_ data: Data, catalogID: UUID?) throws -> URL {
        let identifier = catalogID?.uuidString ?? "Unidentified"
        let folder = try applicationSupportFolder(
            path: "Vitrine/Damaged Catalogs/\(identifier)"
        )
        let stamp = String(Int(Date.now.timeIntervalSince1970 * 1_000))
        let destination = folder.appending(path: "Damaged-Catalog-\(stamp)-\(UUID().uuidString).md")
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func preserveUnrecognizedReplacement(_ data: Data, destinationName: String) throws -> URL {
        let folder = try applicationSupportFolder(path: "Vitrine/Orphaned Catalog Replacements")
        let stamp = String(Int(Date.now.timeIntervalSince1970 * 1_000))
        let safeName = destinationName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let destination = folder.appending(
            path: "Replaced-\(stamp)-\(UUID().uuidString)-\(safeName)"
        )
        try data.write(to: destination, options: .atomic)
        return destination
    }

    func backups(catalogID: UUID) throws -> [Backup] {
        let folder = try backupFolder(catalogID: catalogID)
        return try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "md" }.map {
            Backup(url: $0, date: (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        }.sorted { $0.date > $1.date }
    }

    func unrecognizedReplacementBackups() throws -> [URL] {
        let folder = try applicationSupportFolder(path: "Vitrine/Orphaned Catalog Replacements")
        return try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
    }

    func recoveryArchiveURL() throws -> URL {
        try applicationSupportFolder(path: "Vitrine")
    }

    private func rotate(folder: URL) throws {
        let entries = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
        for url in entries.dropFirst(retentionCount) {
            try fileManager.removeItem(at: url)
        }
    }

    private func backupFolder(catalogID: UUID) throws -> URL {
        try applicationSupportFolder(path: "Vitrine/Backups/\(catalogID.uuidString)")
    }

    private func applicationSupportFolder(path: String) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: path, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
