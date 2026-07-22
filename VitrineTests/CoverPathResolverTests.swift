import XCTest
@testable import Vitrine

final class CoverPathResolverTests: XCTestCase {
    private let resolver = CoverPathResolver()

    func testValidNestedAndUnicodePathsRemainInsideSourceFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let relativePath = "Éditions/Cafe\u{301}.jpg"
        let expected = root.appending(path: relativePath).standardizedFileURL

        XCTAssertEqual(
            try resolver.resolve(relativePath: relativePath, inside: root),
            expected
        )
    }

    func testTraversalAbsoluteMalformedAndRootPathsAreRejected() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        for path in ["../../Outside.jpg", "/tmp/Outside.jpg", "Nested\\Cover.jpg", "Nested//Cover.jpg", ".", ""] {
            XCTAssertThrowsError(try resolver.resolve(relativePath: path, inside: root), path)
        }
    }

    func testSymlinkEscapeIsRejected() throws {
        let root = try makeTemporaryDirectory()
        let outside = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        let link = root.appending(path: "Linked", directoryHint: .isDirectory)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

        XCTAssertThrowsError(
            try resolver.resolve(relativePath: "Linked/Outside.jpg", inside: root)
        )
    }

    @MainActor
    func testInteractiveCoverActionsReportInvalidCatalogPath() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "../../Outside.jpg"))
        let store = CatalogStore(sourceFolderURL: root)
        store.catalog = CatalogSnapshot(name: "Library", items: [item])
        store.selection = item.id

        store.openSelectedCover()
        XCTAssertEqual(store.presentedError?.localizedDescription, CatalogError.invalidCoverPath.localizedDescription)
        store.presentedError = nil
        store.quickLookSelectedCover()
        XCTAssertEqual(store.presentedError?.localizedDescription, CatalogError.invalidCoverPath.localizedDescription)
        store.presentedError = nil
        store.revealSelectedCover()
        XCTAssertEqual(store.presentedError?.localizedDescription, CatalogError.invalidCoverPath.localizedDescription)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
