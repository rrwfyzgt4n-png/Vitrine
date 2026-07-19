import Foundation

struct SourceFileMetadata: Equatable, Sendable {
    var relativePath: String
    var filename: String
    var sourceTitle: String
    var finderComment: String?
    var portableFingerprint: String?
    var fullContentHash: String?
    var fileResourceIdentifier: String?
    var fileSize: Int64?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var fileCreationDate: Date?
    var fileModificationDate: Date?

    init(
        relativePath: String,
        filename: String? = nil,
        sourceTitle: String? = nil,
        finderComment: String? = nil,
        portableFingerprint: String? = nil,
        fullContentHash: String? = nil,
        fileResourceIdentifier: String? = nil,
        fileSize: Int64? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        fileCreationDate: Date? = nil,
        fileModificationDate: Date? = nil
    ) {
        self.relativePath = relativePath
        let lastPathComponent = (relativePath as NSString).lastPathComponent
        self.filename = filename ?? lastPathComponent
        self.sourceTitle = sourceTitle ?? (lastPathComponent as NSString).deletingPathExtension
        self.finderComment = finderComment
        self.portableFingerprint = portableFingerprint
        self.fullContentHash = fullContentHash
        self.fileResourceIdentifier = fileResourceIdentifier
        self.fileSize = fileSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileCreationDate = fileCreationDate
        self.fileModificationDate = fileModificationDate
    }
}
