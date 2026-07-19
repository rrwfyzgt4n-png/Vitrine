import Foundation
import ImageIO

actor ImageMetadataReader {
    func dimensions(for url: URL) throws -> (width: Int, height: Int) {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw CatalogError.imageMetadataReadFailed(url)
        }
        return (width, height)
    }
}
