import Darwin
import XCTest
@testable import Vitrine

final class FinderCommentReaderTests: XCTestCase {
    func testReadsMultilineFinderCommentFromExtendedAttribute() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).jpg")
        try Data([1]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try PropertyListSerialization.data(
            fromPropertyList: "First line\r\nSecond line",
            format: .binary,
            options: 0
        )
        let result = data.withUnsafeBytes { bytes in
            setxattr(url.path, "com.apple.metadata:kMDItemFinderComment", bytes.baseAddress, data.count, 0, 0)
        }
        guard result == 0 else { throw XCTSkip("Extended attributes are unavailable in this test location") }

        let comment = await FinderCommentReader().comment(for: url)

        XCTAssertEqual(comment, "First line\nSecond line")
    }
}
