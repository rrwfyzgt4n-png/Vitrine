import Foundation

enum CatalogFileEvent: Sendable {
    case changed
    case moved(URL)
    case deleted
    case conflictResolved
    case relinquished
    case reacquired
}
