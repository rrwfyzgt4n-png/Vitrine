import XCTest
@testable import Vitrine

final class SecurityScopedBookmarkStoreTests: XCTestCase {
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
}
