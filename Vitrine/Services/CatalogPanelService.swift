import AppKit
import UniformTypeIdentifiers

@MainActor
enum CatalogPanelService {
    static func chooseCoverFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.text("Choose Cover Folder")
        panel.message = L10n.text("Select the folder that contains your book-cover images.")
        panel.prompt = L10n.text("Choose Folder")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseCatalogDestination(for folderURL: URL) -> URL? {
        let panel = NSSavePanel()
        panel.title = L10n.text("Save Your Catalog")
        panel.message = L10n.text("Choose where to save your catalog. iCloud Drive lets the catalog follow you to another Mac.")
        panel.prompt = L10n.text("Save Catalog")
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(folderURL.lastPathComponent) Catalog.md"
        panel.allowedContentTypes = markdownContentTypes
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseCatalogToOpen() -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.text("Open a Vitrine Catalog")
        panel.message = L10n.text("Select a Vitrine Markdown catalog.")
        panel.prompt = L10n.text("Open Catalog")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = markdownContentTypes
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseCatalogCopyDestination(catalogName: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = L10n.text("Export Catalog Copy")
        panel.message = L10n.text("Save a portable Markdown copy. Your cover images are not copied.")
        panel.prompt = L10n.text("Export Copy")
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(catalogName) Copy.md"
        panel.allowedContentTypes = markdownContentTypes
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseCoverFile(in folderURL: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.title = L10n.text("Choose Replacement Cover")
        panel.message = L10n.text("Choose an existing image inside your cover folder. Vitrine will not move or edit it.")
        panel.prompt = L10n.text("Use This Cover")
        panel.directoryURL = folderURL
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .jpeg, .png, .heic, .tiff,
            UTType(filenameExtension: "heif"), UTType(filenameExtension: "webp")
        ].compactMap { $0 }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static var markdownContentTypes: [UTType] {
        [UTType(filenameExtension: "md") ?? .plainText]
    }
}
