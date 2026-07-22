import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let terminationController = ApplicationTerminationController()
    private var flushPendingSaves: (() async throws -> Void)?

    func configureTermination(flushPendingSaves: @escaping () async throws -> Void) {
        self.flushPendingSaves = flushPendingSaves
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        presentMainWindow()
        DispatchQueue.main.async { [weak self] in self?.presentMainWindow() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.presentMainWindow() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { presentMainWindow() }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let flushPendingSaves else { return .terminateNow }
        return terminationController.requestTermination(flush: flushPendingSaves) { [weak self, weak sender] result in
            guard let sender else { return }
            switch result {
            case .success:
                sender.reply(toApplicationShouldTerminate: true)
            case .failure(let error):
                sender.reply(toApplicationShouldTerminate: false)
                self?.presentTerminationSaveFailure(error)
            }
        }
    }

    private func presentMainWindow() {
        let mainWindow = NSApp.windows.first(where: { $0.title == "Vitrine" })
            ?? NSApp.windows.first(where: { $0.canBecomeMain })
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    private func presentTerminationSaveFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.text("Vitrine couldn't save your latest changes")
        alert.informativeText = L10n.text("Vitrine will stay open so your changes are not silently lost. Check the catalog location, then try quitting again.")
        alert.addButton(withTitle: L10n.text("Keep Vitrine Open"))
        alert.window.setAccessibilityLabel(error.localizedDescription)
        alert.runModal()
    }
}

@MainActor
final class ApplicationTerminationController {
    private(set) var isTerminationPending = false
    private let timeout: Duration

    init(timeout: Duration = .seconds(15)) {
        self.timeout = timeout
    }

    func requestTermination(
        flush: @escaping () async throws -> Void,
        completion: @escaping (Result<Void, any Error>) -> Void
    ) -> NSApplication.TerminateReply {
        guard !isTerminationPending else { return .terminateLater }
        isTerminationPending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result: Result<Void, any Error>
            do {
                try await flushWithTimeout(flush)
                result = .success(())
            } catch {
                result = .failure(error)
            }
            isTerminationPending = false
            completion(result)
        }
        return .terminateLater
    }

    private func flushWithTimeout(_ flush: @escaping () async throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            var hasCompleted = false
            let flushTask = Task { @MainActor in
                do {
                    try await flush()
                    guard !hasCompleted else { return }
                    hasCompleted = true
                    continuation.resume()
                } catch {
                    guard !hasCompleted else { return }
                    hasCompleted = true
                    continuation.resume(throwing: error)
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                guard !hasCompleted else { return }
                hasCompleted = true
                flushTask.cancel()
                continuation.resume(throwing: TerminationSaveError.timedOut)
            }
        }
    }
}

private enum TerminationSaveError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        L10n.text("Saving took too long. Vitrine remains open and your catalog has not been discarded.")
    }
}
