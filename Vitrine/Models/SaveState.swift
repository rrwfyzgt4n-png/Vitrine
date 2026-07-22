import Foundation

enum SaveState: Equatable, Sendable {
    case idle
    case pending
    case saving
    case saved(Date)
    case failed(String)
    case readOnly
}
