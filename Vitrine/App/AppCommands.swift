import SwiftUI

struct AppCommands: Commands {
    let store: CatalogStore
    @AppStorage("coverWidth") private var coverWidth = 168.0

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Create New Catalog…") { Task { await store.createCatalog() } }
                .disabled(store.isPerformingCatalogOperation)
            Divider()
            Button("Export Catalog Copy…") { Task { await store.exportCatalogCopy() } }
                .disabled(store.catalog == nil)
            Button("Reveal Catalog in Finder") {
                if let url = store.catalogURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
                .disabled(store.catalogURL == nil)
            Button("Open Catalog in Text Editor") { store.openCatalogInTextEditor() }
                .disabled(store.catalogURL == nil)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Now") { Task { await store.saveNow() } }
                .keyboardShortcut("s")
                .disabled(store.catalog == nil || store.catalog?.isReadOnly == true)
            Button("Open Catalog…") { Task { await store.openCatalog() } }
                .keyboardShortcut("o")
                .disabled(store.isPerformingCatalogOperation)
        }
        CommandMenu("Library") {
            Button("Refresh Covers") { Task { await store.refreshCovers() } }
                .keyboardShortcut("r")
                .disabled(!store.canRefreshCovers)
            Button("Locate Your Cover Folder…") { Task { await store.locateCoverFolder() } }
                .disabled(store.catalog == nil)
            Button("Show Books Needing Review") { store.filter = .needsReview }
                .disabled(store.catalog == nil)
            Divider()
            Menu("Maintenance") {
                Button("Check Catalog Health…") { store.statusMessage = catalogHealthMessage }
                Button("Rebuild Cover Information…") { Task { await store.refreshCovers() } }
                Button("Restore Previous Catalog Version…") { Task { await store.restoreLatestBackup() } }
                    .disabled(store.catalog == nil)
                Button("Show Catalog File in Finder") {
                    if let url = store.catalogURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                Button("Show Local Backups in Finder") { Task { await store.showLocalBackups() } }
                Button("Export Diagnostic Report…") { store.statusMessage = L10n.text("No private catalog information was exported.") }
            }
        }
        CommandMenu("Book") {
            Button("Open Cover") { store.openSelectedCover() }.keyboardShortcut(.return)
                .disabled(store.selectedCoverURL == nil)
            Button("Quick Look") {
                if let url = store.selectedCoverURL { QuickLookService.shared.show(url: url) }
            }.keyboardShortcut(.space).disabled(store.selectedCoverURL == nil)
            Button("Reveal Cover in Finder") { store.revealSelectedCover() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(store.selectedCoverURL == nil)
            Divider()
            Button("Suggest Details from Filename…") { store.suggestDetailsFromFilename() }
                .disabled(store.selectedItem == nil)
            Button("Find Book Details Online…") { Task { await store.findBookDetailsOnline() } }
                .disabled(store.selectedItem == nil)
            Button("Edit Book Details…") { store.isMetadataEditorPresented = true }
                .disabled(store.selectedItem == nil)
            Button("Copy Title") { store.copySelectedTitle() }
                .disabled(store.selectedItem == nil)
            Button("Copy ISBN") { store.copySelectedISBN() }
                .disabled(store.selectedItem?.bibliography.isbn13 == nil && store.selectedItem?.bibliography.isbn10 == nil)
            Button("Keep Without Cover") { Task { await store.keepSelectedWithoutCover() } }
                .disabled(store.selectedItem == nil)
            Divider()
            Button("Remove from Catalog…", role: .destructive) { Task { await store.removeSelectedBook() } }
                .disabled(store.selectedItem == nil)
        }
        CommandGroup(after: .toolbar) {
            Button("Focus Search") { store.focusSearch() }
                .keyboardShortcut("f")
            Button(store.isInspectorPresented ? "Hide Inspector" : "Show Inspector") { store.showInspector() }
                .keyboardShortcut("i")
                .disabled(store.catalog == nil)
            Divider()
            Button("Increase Cover Size") { coverWidth = min(260, coverWidth + 12) }
                .keyboardShortcut("+")
            Button("Decrease Cover Size") { coverWidth = max(120, coverWidth - 12) }
                .keyboardShortcut("-")
            Button("Reset Cover Size") { coverWidth = 168 }
        }
    }

    private var catalogHealthMessage: String {
        guard let catalog = store.catalog else { return L10n.text("No catalog is open.") }
        let unavailable = catalog.items.filter { $0.availability != .available }.count
        return unavailable == 0
            ? String(localized: "Your catalog is healthy. \(catalog.items.count) books found.")
            : String(localized: "Your catalog contains \(catalog.items.count) books. \(unavailable) covers need attention.")
    }
}
