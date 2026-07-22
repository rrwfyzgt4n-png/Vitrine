import Foundation

struct NewCatalogRecord: Equatable, Sendable {
    var item: CatalogItem
}

struct FileCandidate: Equatable, Sendable {
    var relativePath: String
    var portableFingerprint: String?
}

enum CatalogReconciliationOperation: Equatable, Sendable {
    case addRecord(NewCatalogRecord)
    case updateSource(id: UUID, expected: SourceRevision, newValue: SourceFileMetadata)
    case updatePath(id: UUID, expected: SourceRevision, newPath: String, newTitle: String)
    case updateFinderComment(id: UUID, expected: SourceRevision, comment: String?)
    case markMissing(id: UUID, expected: SourceRevision)
    case markAvailable(id: UUID, expected: SourceRevision)
    case markAmbiguous(id: UUID, candidates: [FileCandidate])
    case removeRecord(id: UUID, expected: SourceRevision)
}
