import Foundation

enum ScanState: Equatable, Sendable {
    case idle
    case refreshing(completed: Int, total: Int?)
    case completed(warnings: Int)
    case failed(String)
}
