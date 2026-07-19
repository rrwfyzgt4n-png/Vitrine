import XCTest
@testable import Vitrine

final class FilenameTitleTests: XCTestCase {
    func testSourceTitleRemovesOnlyFinalExtension() {
        let metadata = SourceFileMetadata(relativePath: "Kafka/The.Trial.jpg")

        XCTAssertEqual(metadata.filename, "The.Trial.jpg")
        XCTAssertEqual(metadata.sourceTitle, "The.Trial")
    }

    func testSourceTitlePreservesUnderscoresAndCapitalization() {
        let metadata = SourceFileMetadata(relativePath: "Classics/THE_TRIAL.JPEG")

        XCTAssertEqual(metadata.sourceTitle, "THE_TRIAL")
    }
}
