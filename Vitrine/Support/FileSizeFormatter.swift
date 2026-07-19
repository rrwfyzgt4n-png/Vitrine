import Foundation

enum CatalogFileSizeFormatter {
    static func string(fromByteCount count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }
}
