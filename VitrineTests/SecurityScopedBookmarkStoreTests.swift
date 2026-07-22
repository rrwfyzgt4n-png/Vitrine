import XCTest
@testable import Vitrine

final class SecurityScopedBookmarkStoreTests: XCTestCase {
    func testRemountMatchesStableIdentityAndRejectsUnrelatedSameNameVolume() {
        let expectedURL = URL(fileURLWithPath: "/Volumes/Library Disk")
        let unrelatedURL = URL(fileURLWithPath: "/Volumes/Library Disk 1")
        let identity = VolumeIdentity(
            uuid: "EXPECTED-UUID",
            resourceIdentifier: "EXPECTED-RESOURCE",
            displayName: "Library Disk",
            lastKnownURL: expectedURL,
            relativeFolderPath: "Covers"
        )
        let candidates = [
            MountedVolumeCandidate(
                url: unrelatedURL,
                uuid: "UNRELATED-UUID",
                resourceIdentifier: "UNRELATED-RESOURCE"
            ),
            MountedVolumeCandidate(
                url: expectedURL,
                uuid: "EXPECTED-UUID",
                resourceIdentifier: "NEW-RESOURCE-REPRESENTATION"
            ),
        ]

        XCTAssertEqual(
            VolumeReconnectMatcher().matchingVolume(for: identity, candidates: candidates),
            expectedURL
        )
        XCTAssertNil(
            VolumeReconnectMatcher().matchingVolume(for: identity, candidates: [candidates[0]])
        )
    }

    func testVolumeNameAloneIsNeverAcceptedForRemount() {
        let identity = VolumeIdentity(
            uuid: nil,
            resourceIdentifier: nil,
            displayName: "Same Name",
            lastKnownURL: nil,
            relativeFolderPath: "Covers"
        )
        let candidate = MountedVolumeCandidate(
            url: URL(fileURLWithPath: "/Volumes/Same Name"),
            uuid: "SOME-OTHER-UUID",
            resourceIdentifier: "SOME-OTHER-RESOURCE"
        )

        XCTAssertNil(VolumeReconnectMatcher().matchingVolume(for: identity, candidates: [candidate]))
    }

    func testSaveAndResolveLastCatalogAndCoverFolder() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let covers = root.appending(path: "Covers", directoryHint: .isDirectory)
        let catalogURL = root.appending(path: "Library.md")
        let accessURL = root.appending(path: "Application Support/CatalogAccess.plist")
        try FileManager.default.createDirectory(at: covers, withIntermediateDirectories: true)
        try Data("catalog".utf8).write(to: catalogURL)
        defer { try? FileManager.default.removeItem(at: root) }

        let id = UUID()
        let snapshot = CatalogSnapshot(
            catalogID: id,
            name: "Library",
            sourceFolderName: "Covers",
            sourceFolderSignature: "signature"
        )
        let store = SecurityScopedBookmarkStore(storageURL: accessURL)

        try await store.save(catalogURL: catalogURL, coverFolderURL: covers, snapshot: snapshot)
        let resolved = try await store.resolveLast()

        XCTAssertEqual(resolved?.catalogID, id)
        XCTAssertEqual(resolved?.catalogURL.standardizedFileURL, catalogURL.standardizedFileURL)
        XCTAssertEqual(resolved?.coverFolderURL?.standardizedFileURL, covers.standardizedFileURL)
        XCTAssertEqual(resolved?.sourceFolderSignature, "signature")
        XCTAssertTrue(FileManager.default.fileExists(atPath: accessURL.path))
    }

    func testCatalogOnlyAccessRemainsResolvable() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let catalogURL = root.appending(path: "Library.md")
        let accessURL = root.appending(path: "Support/CatalogAccess.plist")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("catalog".utf8).write(to: catalogURL)
        defer { try? FileManager.default.removeItem(at: root) }

        let snapshot = CatalogSnapshot(name: "Library")
        let store = SecurityScopedBookmarkStore(storageURL: accessURL)
        try await store.save(catalogURL: catalogURL, coverFolderURL: nil, snapshot: snapshot)

        let resolved = try await store.resolveLast()
        XCTAssertEqual(resolved?.catalogID, snapshot.catalogID)
        XCTAssertNil(resolved?.coverFolderURL)
    }

    func testUnavailableFolderDoesNotEraseRememberedAccess() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let covers = root.appending(path: "Covers", directoryHint: .isDirectory)
        let catalogURL = root.appending(path: "Library.md")
        let accessURL = root.appending(path: "Support/CatalogAccess.plist")
        try FileManager.default.createDirectory(at: covers, withIntermediateDirectories: true)
        try Data("catalog".utf8).write(to: catalogURL)
        defer { try? FileManager.default.removeItem(at: root) }

        let snapshot = CatalogSnapshot(
            name: "Library",
            sourceFolderName: "Covers",
            sourceFolderSignature: "signature"
        )
        let store = SecurityScopedBookmarkStore(storageURL: accessURL)
        try await store.save(catalogURL: catalogURL, coverFolderURL: covers, snapshot: snapshot)
        let before = try PropertyListDecoder().decode(
            CatalogAccessFile.self,
            from: Data(contentsOf: accessURL)
        )

        try FileManager.default.removeItem(at: covers)
        try await store.save(
            catalogURL: catalogURL,
            coverFolderURL: nil,
            snapshot: snapshot,
            preserveExistingCoverAccess: true
        )

        let after = try PropertyListDecoder().decode(
            CatalogAccessFile.self,
            from: Data(contentsOf: accessURL)
        )
        XCTAssertEqual(
            after.records[snapshot.catalogID]?.coverFolderBookmark,
            before.records[snapshot.catalogID]?.coverFolderBookmark
        )
        XCTAssertEqual(
            after.records[snapshot.catalogID]?.volumeIdentity,
            before.records[snapshot.catalogID]?.volumeIdentity
        )
        let resolved = try await store.resolveLast()
        XCTAssertNil(resolved?.coverFolderURL)
    }
}
