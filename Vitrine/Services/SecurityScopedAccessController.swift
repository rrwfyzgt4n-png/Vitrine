import Foundation

final class SecurityScopeLease: @unchecked Sendable {
    let url: URL
    private let lock = NSLock()
    private var isActive: Bool

    init(url: URL) {
        self.url = url
        isActive = url.startAccessingSecurityScopedResource()
    }

    func stop() {
        lock.withLock {
            guard isActive else { return }
            url.stopAccessingSecurityScopedResource()
            isActive = false
        }
    }

    deinit {
        stop()
    }
}

@MainActor
final class SecurityScopedAccessController {
    private(set) var catalogLease: SecurityScopeLease?
    private(set) var coverFolderLease: SecurityScopeLease?

    func replace(catalogURL: URL, coverFolderURL: URL?) {
        let nextCatalogLease = SecurityScopeLease(url: catalogURL)
        let nextFolderLease = coverFolderURL.map(SecurityScopeLease.init(url:))
        coverFolderLease?.stop()
        catalogLease?.stop()
        catalogLease = nextCatalogLease
        coverFolderLease = nextFolderLease
    }

    func replaceCoverFolder(with url: URL?) {
        let nextLease = url.map(SecurityScopeLease.init(url:))
        coverFolderLease?.stop()
        coverFolderLease = nextLease
    }

    func releaseAll() {
        coverFolderLease?.stop()
        catalogLease?.stop()
        coverFolderLease = nil
        catalogLease = nil
    }
}
