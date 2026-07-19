import Foundation

struct CatalogAccessRecord: Codable, Equatable, Sendable {
    var catalogID: UUID
    var catalogBookmark: Data
    var coverFolderBookmark: Data?
    var volumeUUID: String?
    var volumeName: String?
    var relativeFolderPath: String?
    var sourceFolderSignature: String?
    var volumeIdentity: VolumeIdentity?
    var updatedAt: Date
}

struct CatalogAccessFile: Codable, Equatable, Sendable {
    var lastCatalogID: UUID?
    var records: [UUID: CatalogAccessRecord]

    static let empty = CatalogAccessFile(lastCatalogID: nil, records: [:])
}
