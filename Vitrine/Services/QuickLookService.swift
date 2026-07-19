import AppKit
import Quartz

@MainActor
final class QuickLookService: NSObject, @preconcurrency QLPreviewPanelDataSource {
    static let shared = QuickLookService()
    private var previewURL: URL?

    func show(url: URL) {
        previewURL = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> any QLPreviewItem {
        previewURL! as NSURL
    }
}
