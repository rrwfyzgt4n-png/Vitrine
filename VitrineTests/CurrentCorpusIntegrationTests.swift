import XCTest
@testable import Vitrine

final class CurrentCorpusIntegrationTests: XCTestCase {
    func testCurrentCatalogMatchesItsSupportedCoverCorpus() async throws {
        let folder = URL(fileURLWithPath: "/Volumes/FastData/Téléchargements/libcat", isDirectory: true)
        let catalogURL = folder.appending(path: "libcat Catalog.md")
        guard FileManager.default.fileExists(atPath: catalogURL.path) else {
            throw XCTSkip("The user's removable-volume corpus is not mounted")
        }

        let snapshot = try await CatalogMarkdownStore().read(from: catalogURL).snapshot
        let scan = try await CatalogScanner().scan(folderURL: folder)
        let diff = await CatalogReconciler().diff(catalog: snapshot, scan: scan)
        let removals = diff.operations.filter { if case .removeRecord = $0 { true } else { false } }
        let additions = diff.operations.filter { if case .addRecord = $0 { true } else { false } }

        XCTAssertTrue(scan.completedEnumeration)
        XCTAssertEqual(snapshot.items.count, scan.sources.count)
        XCTAssertTrue(removals.isEmpty)
        XCTAssertTrue(additions.isEmpty)
    }
}
