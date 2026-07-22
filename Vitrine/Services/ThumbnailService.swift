import CoreGraphics
import Foundation
import ImageIO

struct ThumbnailImage: @unchecked Sendable {
    let cgImage: CGImage
}

struct ThumbnailCacheStatistics: Equatable, Sendable {
    var hits: Int
    var misses: Int
    var countLimit: Int
    var totalCostLimit: Int
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
    private let pathResolver = CoverPathResolver()
    private var cacheHits = 0
    private var cacheMisses = 0
    private let countLimit = 500
    private let totalCostLimit = 256 * 1_024 * 1_024

    init() {
        cache = NSCache<NSString, CachedThumbnail>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    func thumbnail(
        sourceFolderURL: URL,
        source: SourceFileMetadata,
        maximumPixelSize: Int
    ) throws -> ThumbnailImage {
        try Task.checkCancellation()
        let fileURL = try pathResolver.resolve(
            relativePath: source.relativePath,
            inside: sourceFolderURL
        )
        let cacheKey = NSString(string: [
            fileURL.path(percentEncoded: false),
            source.fileSize.map(String.init) ?? "unknown-size",
            source.fileModificationDate.map { String($0.timeIntervalSince1970) } ?? "unknown-date",
            String(maximumPixelSize)
        ].joined(separator: "|"))

        if let cached = cache.object(forKey: cacheKey) {
            cacheHits += 1
            return ThumbnailImage(cgImage: cached.image)
        }
        cacheMisses += 1

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
        cacheHits = 0
        cacheMisses = 0
    }

    func statistics() -> ThumbnailCacheStatistics {
        ThumbnailCacheStatistics(
            hits: cacheHits,
            misses: cacheMisses,
            countLimit: countLimit,
            totalCostLimit: totalCostLimit
        )
    }
}
