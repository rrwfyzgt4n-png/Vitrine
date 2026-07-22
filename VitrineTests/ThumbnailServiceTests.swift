import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Vitrine

final class ThumbnailServiceTests: XCTestCase {
    func testThumbnailDownsamplesJPEGToRequestedPixelSize() async throws {
        let temporaryFolderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: temporaryFolderURL) }

        let imageURL = temporaryFolderURL.appendingPathComponent("Cover.jpg")
        try writeJPEG(to: imageURL, width: 1_200, height: 1_800)
        let resourceValues = try imageURL.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
        ])
        let source = SourceFileMetadata(
            relativePath: "Cover.jpg",
            fileSize: Int64(resourceValues.fileSize ?? 0),
            fileModificationDate: resourceValues.contentModificationDate
        )
        let thumbnail = try await ThumbnailService().thumbnail(
            sourceFolderURL: temporaryFolderURL,
            source: source,
            maximumPixelSize: 240
        )

        XCTAssertLessThanOrEqual(max(thumbnail.cgImage.width, thumbnail.cgImage.height), 240)
        XCTAssertGreaterThan(thumbnail.cgImage.width, 0)
        XCTAssertGreaterThan(thumbnail.cgImage.height, 0)
    }

    func testRepeatedThumbnailRequestUsesBoundedCache() async throws {
        let temporaryFolderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryFolderURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryFolderURL) }
        let imageURL = temporaryFolderURL.appendingPathComponent("Cover.jpg")
        try writeJPEG(to: imageURL, width: 1_200, height: 1_800)
        let values = try imageURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let source = SourceFileMetadata(
            relativePath: "Cover.jpg",
            fileSize: Int64(values.fileSize ?? 0),
            fileModificationDate: values.contentModificationDate
        )
        let service = ThumbnailService()

        _ = try await service.thumbnail(sourceFolderURL: temporaryFolderURL, source: source, maximumPixelSize: 240)
        _ = try await service.thumbnail(sourceFolderURL: temporaryFolderURL, source: source, maximumPixelSize: 240)
        let statistics = await service.statistics()

        XCTAssertEqual(statistics.misses, 1)
        XCTAssertEqual(statistics.hits, 1)
        XCTAssertEqual(statistics.countLimit, 500)
        XCTAssertEqual(statistics.totalCostLimit, 256 * 1_024 * 1_024)
    }

    private func writeJPEG(to url: URL, width: Int, height: Int) throws {
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.45, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}
