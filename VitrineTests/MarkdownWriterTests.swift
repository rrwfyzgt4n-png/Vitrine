import XCTest
@testable import Vitrine

final class MarkdownWriterTests: XCTestCase {
    func testWriterIsDeterministicAndSortsRecords() throws {
        let date = try XCTUnwrap(CatalogDateFormatter.date(from: "2026-07-18T20:00:00Z"))
        let second = CatalogItem(
            id: UUID(uuidString: "86CC391A-4662-4553-902D-E8B80D2641DD")!,
            source: SourceFileMetadata(relativePath: "Kafka/The Trial.jpg"),
            bibliography: .init(title: "The Trial", authors: ["Franz Kafka"], metadataSource: .manual, metadataConfirmedByUser: true),
            dateAdded: date,
            dateModified: date
        )
        let first = CatalogItem(
            id: UUID(uuidString: "6E0B21A4-4763-47D9-A3B1-4A8853CB818B")!,
            source: SourceFileMetadata(relativePath: "Austen/Emma.jpg"),
            dateAdded: date,
            dateModified: date
        )
        let snapshot = CatalogSnapshot(
            catalogID: UUID(uuidString: "9A50D16E-51E8-4867-B81E-2525F910AD51")!,
            name: "My Library",
            createdAt: date,
            updatedAt: date,
            items: [second, first]
        )

        let writer = CatalogMarkdownWriter()
        let rendered = try writer.render(snapshot)

        XCTAssertEqual(rendered, try writer.render(snapshot))
        XCTAssertLessThan(try XCTUnwrap(rendered.range(of: "## Emma")?.lowerBound), try XCTUnwrap(rendered.range(of: "## The Trial")?.lowerBound))
        XCTAssertTrue(rendered.hasSuffix("\n"))
        XCTAssertFalse(rendered.contains("\r"))
    }

    func testReadOnlyCatalogCannotBeRendered() {
        let snapshot = CatalogSnapshot(schemaVersion: 2, name: "Future", isReadOnly: true)

        XCTAssertThrowsError(try CatalogMarkdownWriter().render(snapshot))
    }
}
