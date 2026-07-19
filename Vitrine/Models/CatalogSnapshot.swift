import Foundation

struct CatalogSnapshot: Equatable, Sendable {
    static let supportedSchemaVersion = 1

    var schemaVersion: Int
    var catalogID: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var sourceFolderName: String?
    var sourceFolderSignature: String?
    var items: [CatalogItem]
    var unknownFrontMatter: [String: String]
    var unmanagedText: String
    var isReadOnly: Bool

    init(
        schemaVersion: Int = Self.supportedSchemaVersion,
        catalogID: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sourceFolderName: String? = nil,
        sourceFolderSignature: String? = nil,
        items: [CatalogItem] = [],
        unknownFrontMatter: [String: String] = [:],
        unmanagedText: String = "",
        isReadOnly: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.catalogID = catalogID
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceFolderName = sourceFolderName
        self.sourceFolderSignature = sourceFolderSignature
        self.items = items
        self.unknownFrontMatter = unknownFrontMatter
        self.unmanagedText = unmanagedText
        self.isReadOnly = isReadOnly
    }
}
