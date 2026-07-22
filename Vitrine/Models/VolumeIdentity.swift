import Foundation

struct VolumeIdentity: Codable, Equatable, Sendable {
    var uuid: String?
    var resourceIdentifier: String?
    var displayName: String?
    var lastKnownURL: URL?
    var relativeFolderPath: String?
}
