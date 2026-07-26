import Foundation

final class CatalogFilePresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    let presentedItemURL: URL?
    let presentedItemOperationQueue: OperationQueue
    let events: AsyncStream<CatalogFileEvent>
    private let continuation: AsyncStream<CatalogFileEvent>.Continuation

    init(url: URL) {
        presentedItemURL = url
        let queue = OperationQueue()
        queue.name = "Vitrine.CatalogFilePresenter"
        queue.maxConcurrentOperationCount = 1
        presentedItemOperationQueue = queue
        // This stream is the sole event buffer. CatalogStore consumes it serially and
        // waits for active catalog operations instead of maintaining a second queue.
        // Every event therefore remains ordered until full state can be re-read.
        let pair = AsyncStream<CatalogFileEvent>.makeStream(bufferingPolicy: .unbounded)
        events = pair.stream
        continuation = pair.continuation
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    func stop() {
        NSFileCoordinator.removeFilePresenter(self)
        continuation.finish()
    }

    func presentedItemDidChange() {
        continuation.yield(.changed)
    }

    func presentedItemDidMove(to newURL: URL) {
        continuation.yield(.moved(newURL))
    }

    func accommodatePresentedItemDeletion(completionHandler: @escaping @Sendable (Error?) -> Void) {
        continuation.yield(.deleted)
        completionHandler(nil)
    }

    func presentedItemDidResolveConflict(_ version: NSFileVersion) {
        continuation.yield(.conflictResolved)
    }

    func relinquishPresentedItem(
        toReader reader: @escaping @Sendable ((@Sendable () -> Void)?) -> Void
    ) {
        // NSFileCoordinator invokes this for Vitrine's own reads too. Those
        // accesses are not external catalog changes and must not feed back into
        // the presenter's change stream.
        reader({})
    }

    func relinquishPresentedItem(
        toWriter writer: @escaping @Sendable ((@Sendable () -> Void)?) -> Void
    ) {
        // presentedItemDidChange remains the authoritative change notification.
        // Emitting reacquisition here creates a read/reacquire feedback loop.
        writer({})
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
        continuation.finish()
    }
}
