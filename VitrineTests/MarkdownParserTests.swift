import XCTest
@testable import Vitrine

final class MarkdownParserTests: XCTestCase {
    func testParserRecoversValidRecordsAroundMalformedRecord() throws {
        let source = """
        ---
        library-catalog-schema: 1
        catalog-id: 9A50D16E-51E8-4867-B81E-2525F910AD51
        catalog-name: Recovery Test
        created-at: 2026-07-18T20:00:00Z
        updated-at: 2026-07-18T20:00:00Z
        record-count: 2
        ---
        # Recovery Test

        <!-- library-catalog:item:begin id="86CC391A-4662-4553-902D-E8B80D2641DD" -->
        ## The Trial
        - source-file: `Kafka/The Trial.jpg`
        - source-title: `The Trial`
        - availability: `available`
        - date-added: `2026-07-18T20:00:00Z`
        - record-modified: `2026-07-18T20:00:00Z`
        <!-- library-catalog:item:end -->

        <!-- library-catalog:item:begin id="6E0B21A4-4763-47D9-A3B1-4A8853CB818B" -->
        ## Broken
        - source-title: `Broken`
        <!-- library-catalog:item:end -->
        """

        let result = try CatalogMarkdownParser().parse(source)

        XCTAssertEqual(result.snapshot.items.map(\.source.sourceTitle), ["The Trial"])
        XCTAssertTrue(result.diagnostics.contains { $0.code == .missingRequiredField })
        XCTAssertTrue(result.diagnostics.contains { $0.code == .recordCountMismatch })
    }

    func testNewerSchemaOpensReadOnly() throws {
        let source = """
        ---
        library-catalog-schema: 99
        catalog-id: 9A50D16E-51E8-4867-B81E-2525F910AD51
        catalog-name: Future
        created-at: 2026-07-18T20:00:00Z
        updated-at: 2026-07-18T20:00:00Z
        record-count: 0
        ---
        # Future
        """

        let result = try CatalogMarkdownParser().parse(source)

        XCTAssertTrue(result.snapshot.isReadOnly)
        XCTAssertTrue(result.diagnostics.contains { $0.code == .unsupportedSchema })
    }

    func testDuplicateRecordIDCannotReplaceFirstAcceptedRecord() throws {
        let duplicateID = "86CC391A-4662-4553-902D-E8B80D2641DD"
        let source = """
        ---
        library-catalog-schema: 1
        catalog-id: 9A50D16E-51E8-4867-B81E-2525F910AD51
        catalog-name: Duplicate Test
        created-at: 2026-07-18T20:00:00Z
        updated-at: 2026-07-18T20:00:00Z
        record-count: 2
        ---
        # Duplicate Test

        <!-- library-catalog:item:begin id="\(duplicateID)" -->
        ## First
        - source-file: `First.jpg`
        - source-title: `First`
        <!-- library-catalog:item:end -->

        <!-- library-catalog:item:begin id="\(duplicateID)" -->
        ## Second
        - source-file: `Second.jpg`
        - source-title: `Second`
        <!-- library-catalog:item:end -->
        """

        let result = try CatalogMarkdownParser().parse(source)

        XCTAssertEqual(result.snapshot.items.count, 1)
        XCTAssertEqual(result.snapshot.items[0].source.relativePath, "First.jpg")
        XCTAssertTrue(result.diagnostics.contains { $0.code == .duplicateRecordID })
        XCTAssertTrue(result.diagnostics.contains { $0.code == .recordCountMismatch })
    }
}
