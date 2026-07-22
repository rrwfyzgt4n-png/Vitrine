import Foundation

struct MountedVolumeCandidate: Equatable, Sendable {
    var url: URL
    var uuid: String?
    var resourceIdentifier: String?
}

struct VolumeReconnectMatcher: Sendable {
    func matchingVolume(
        for identity: VolumeIdentity,
        candidates: [MountedVolumeCandidate]
    ) -> URL? {
        candidates.first { candidate in
            if let expectedUUID = identity.uuid {
                return candidate.uuid == expectedUUID
            }
            if let expectedResourceIdentifier = identity.resourceIdentifier {
                return candidate.resourceIdentifier == expectedResourceIdentifier
            }
            return false
        }?.url
    }
}
