import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Vitrine

final class CatalogScannerTests: XCTestCase {
    func testScannerFindsNestedJPEGsAndIgnoresOtherFiles() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let nested = root.appending(path: "Kafka", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeImage(to: nested.appending(path: "The Trial.JPG"), type: .jpeg)
        try writeImage(to: root.appending(path: "Cover.png"), type: .png)
        try Data("not an image".utf8).write(to: root.appending(path: "Notes.txt"))
        try Data().write(to: root.appending(path: "Empty.jpeg"))

        let result = try await CatalogScanner().scan(folderURL: root)

        XCTAssertEqual(result.sources.map(\.relativePath), ["Cover.png", "Kafka/The Trial.JPG"])
        XCTAssertEqual(result.sources.last?.sourceTitle, "The Trial")
        XCTAssertEqual(result.sources.last?.pixelWidth, 30)
        XCTAssertEqual(result.sources.last?.pixelHeight, 40)
        XCTAssertTrue(result.completedEnumeration)
    }

    func testCorruptSupportedImageMakesScanIncomplete() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("not an image".utf8).write(to: root.appending(path: "Damaged.webp"))

        let result = try await CatalogScanner().scan(folderURL: root)

        XCTAssertFalse(result.completedEnumeration)
        XCTAssertEqual(result.warnings.map(\.relativePath), ["Damaged.webp"])
    }

    func testDuplicatePartialFingerprintsReceiveFullHashes() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appending(path: "First.jpg")
        try writeImage(to: first, type: .jpeg)
        try FileManager.default.copyItem(at: first, to: root.appending(path: "Second.jpg"))

        let result = try await CatalogScanner().scan(folderURL: root)

        XCTAssertEqual(Set(result.sources.compactMap(\.portableFingerprint)).count, 1)
        XCTAssertEqual(Set(result.sources.compactMap(\.fullContentHash)).count, 1)
        XCTAssertEqual(result.sources.compactMap(\.fullContentHash).count, 2)
    }

    func testScannerReportsBoundedProgressThroughCompletion() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try writeImage(to: root.appending(path: "First.jpg"), type: .jpeg)
        try writeImage(to: root.appending(path: "Second.png"), type: .png)
        for index in 3...199 {
            try Data().write(to: root.appending(path: "Unreadable \(index).jpg"))
        }
        try Data("ignored".utf8).write(to: root.appending(path: "Notes.txt"))
        let recorder = ScanProgressRecorder()

        _ = try await CatalogScanner().scan(folderURL: root) { progress in
            await recorder.append(progress)
        }

        let values = await recorder.values
        XCTAssertEqual(values.first, CatalogScanProgress(completed: 0, total: 199))
        XCTAssertEqual(values.last, CatalogScanProgress(completed: 199, total: 199))
        XCTAssertTrue(values.allSatisfy { $0.completed >= 0 && $0.completed <= $0.total })
        XCTAssertLessThanOrEqual(values.count, 102)
    }

    func testAllSupportedExtensionsAndUnicodePathsAreScanned() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let jpeg = root.appending(path: "Café.jpg")
        let png = root.appending(path: "Cover.PNG")
        let tiff = root.appending(path: "Cover.TIFF")
        let heic = root.appending(path: "Cover.HEIC")
        let webp = root.appending(path: "Cover.webp")
        try writeImage(to: jpeg, type: .jpeg)
        try writeImage(to: png, type: .png)
        try writeImage(to: tiff, type: .tiff)
        try writeImage(to: heic, type: .heic)
        try XCTUnwrap(Data(base64Encoded: "UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA")).write(to: webp)
        try FileManager.default.copyItem(at: jpeg, to: root.appending(path: "Alias.JPEG"))
        try FileManager.default.copyItem(at: heic, to: root.appending(path: "Alias.heif"))
        try FileManager.default.copyItem(at: tiff, to: root.appending(path: "Alias.tif"))

        let result = try await CatalogScanner().scan(folderURL: root)

        XCTAssertTrue(result.completedEnumeration)
        XCTAssertEqual(Set(result.sources.map { $0.relativePath.lowercased().split(separator: ".").last! }),
                       Set(["jpg", "jpeg", "png", "tiff", "tif", "heic", "heif", "webp"]))
        XCTAssertTrue(result.sources.contains { $0.sourceTitle.precomposedStringWithCanonicalMapping == "Café" })
    }

    private func writeImage(to url: URL, type: UTType) throws {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 30,
            height: 40,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.4, green: 0.2, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 30, height: 40))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}

private actor ScanProgressRecorder {
    private(set) var values: [CatalogScanProgress] = []

    func append(_ progress: CatalogScanProgress) {
        values.append(progress)
    }
}
