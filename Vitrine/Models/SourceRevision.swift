import Foundation

struct SourceRevision: Equatable, Sendable {
    var relativePath: String
    var portableFingerprint: String?
    var fileModificationDate: Date?
}
