import Foundation

enum CatalogFileEvent: Equatable, Sendable {
    case changed
    case moved(URL)
    case deleted
    case conflictResolved
    case relinquished
    case reacquired
}
