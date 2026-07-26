import Foundation

struct CatalogScanProgress: Equatable, Sendable {
    var completed: Int
    var total: Int
}

enum ScanState: Equatable, Sendable {
    case idle
    case refreshing(completed: Int, total: Int?)
    case completed(warnings: Int)
    case failed(String)
}
