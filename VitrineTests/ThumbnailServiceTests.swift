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
