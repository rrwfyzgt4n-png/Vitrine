import CoreGraphics
import Foundation
import ImageIO

struct ThumbnailImage: @unchecked Sendable {
    let cgImage: CGImage
}

actor ThumbnailService {
    static let shared = ThumbnailService()

    private final class CachedThumbnail: NSObject {
        let image: CGImage

        init(image: CGImage) {
            self.image = image
        }
    }

    private let cache: NSCache<NSString, CachedThumbnail>

    init() {
        cache = NSCache<NSString, CachedThumbnail>()
        cache.countLimit = 500
        cache.totalCostLimit = 256 * 1_024 * 1_024
    }

    func thumbnail(
        sourceFolderURL: URL,
        source: SourceFileMetadata,
        maximumPixelSize: Int
    ) throws -> ThumbnailImage {
        try Task.checkCancellation()
        let fileURL = try coverURL(sourceFolderURL: sourceFolderURL, relativePath: source.relativePath)
        let cacheKey = NSString(string: [
            fileURL.path(percentEncoded: false),
            source.fileSize.map(String.init) ?? "unknown-size",
            source.fileModificationDate.map { String($0.timeIntervalSince1970) } ?? "unknown-date",
            String(maximumPixelSize)
        ].joined(separator: "|"))

        if let cached = cache.object(forKey: cacheKey) {
            return ThumbnailImage(cgImage: cached.image)
        }

        let isAccessing = sourceFolderURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { sourceFolderURL.stopAccessingSecurityScopedResource() }
        }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, sourceOptions) else {
            throw CatalogError.thumbnailGenerationFailed(fileURL)
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maximumPixelSize),
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions) else {
            throw CatalogError.thumbnailGenerationFailed(fileURL)
        }

        try Task.checkCancellation()
        cache.setObject(
            CachedThumbnail(image: image),
            forKey: cacheKey,
            cost: image.bytesPerRow * image.height
        )
        return ThumbnailImage(cgImage: image)
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private func coverURL(sourceFolderURL: URL, relativePath: String) throws -> URL {
        let root = sourceFolderURL.resolvingSymlinksInPath().standardizedFileURL
        let fileURL = root.appending(path: relativePath).resolvingSymlinksInPath().standardizedFileURL
        let rootComponents = root.pathComponents
        let fileComponents = fileURL.pathComponents
        guard fileComponents.count > rootComponents.count,
              Array(fileComponents.prefix(rootComponents.count)) == rootComponents else {
            throw CatalogError.thumbnailGenerationFailed(fileURL)
        }
        return fileURL
    }
}
