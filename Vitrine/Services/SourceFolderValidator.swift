import CryptoKit
import Foundation

struct SourceFolderValidator: Sendable {
    func signature(folderName: String, sources: [SourceFileMetadata], catalogID: UUID) -> String {
        let sample = sources.map(\.relativePath).sorted().prefix(12).joined(separator: "|")
        let value = "\(catalogID.uuidString)|\(folderName)|\(sources.count)|\(sample)"
        return SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func looksLikeCatalogFolder(catalog: CatalogSnapshot, sources: [SourceFileMetadata], folderName: String) -> Bool {
        guard !catalog.items.isEmpty else { return true }
        if let expectedName = catalog.sourceFolderName, !expectedName.isEmpty,
           SearchNormalizer.normalize(expectedName) != SearchNormalizer.normalize(folderName) {
            return false
        }
        let knownPaths = Set(catalog.items.map { $0.source.relativePath })
        let knownFingerprints = Set(catalog.items.compactMap { $0.source.portableFingerprint })
        return sources.contains {
            knownPaths.contains($0.relativePath) || ($0.portableFingerprint.map(knownFingerprints.contains) ?? false)
        }
    }
}
