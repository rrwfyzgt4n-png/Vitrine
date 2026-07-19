import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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

    private func presentMainWindow() {
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }
}
