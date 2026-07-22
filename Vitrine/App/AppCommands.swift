import SwiftUI

struct AppCommands: Commands {
    let store: CatalogStore
    @Environment(\.openWindow) private var openWindow
    @AppStorage("coverWidth") private var coverWidth = 168.0

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Vitrine") { openWindow(id: "about") }
        }
        CommandGroup(replacing: .newItem) {
            Button("Create New Catalog…") { Task { _ = await store.createCatalog() } }
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
            Button(CatalogFilter.all.label) { store.filter = .all }
                .disabled(store.catalog == nil || store.filter == .all)
            Button("Show Books Needing Review") { store.filter = .needsReview }
                .disabled(store.catalog == nil)
            Divider()
            Menu("Maintenance") {
                Button("Check Catalog Health…") { Task { await store.checkCatalogHealth() } }
                    .disabled(store.catalog == nil)
                Button("Rebuild Cover Information…") { Task { await store.rebuildCoverInformation() } }
                    .disabled(!store.canRefreshCovers)
                Button("Restore Previous Catalog Version…") { Task { await store.restoreLatestBackup() } }
                    .disabled(store.catalog == nil || store.catalog?.isReadOnly == true)
                Button("Show Catalog File in Finder") {
                    if let url = store.catalogURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                    .disabled(store.catalogURL == nil)
                Button("Show Local Backups in Finder") { Task { await store.showLocalBackups() } }
                    .disabled(store.catalog == nil)
                Button("Export Diagnostic Report…") { Task { await store.exportDiagnosticReport() } }
                    .disabled(store.catalog == nil)
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
                .disabled(store.selectedItem == nil || store.catalog?.isReadOnly == true)
            Button("Find Book Details Online…") { Task { await store.findBookDetailsOnline() } }
                .disabled(store.selectedItem == nil || store.catalog?.isReadOnly == true)
            Button("Edit Book Details…") { store.isMetadataEditorPresented = true }
                .disabled(store.selectedItem == nil || store.catalog?.isReadOnly == true)
            Button("Copy Title") { store.copySelectedTitle() }
                .disabled(store.selectedItem == nil)
            Button("Copy ISBN") { store.copySelectedISBN() }
                .disabled(store.selectedItem?.bibliography.isbn13 == nil && store.selectedItem?.bibliography.isbn10 == nil)
            Button("Keep Without Cover") { Task { await store.keepSelectedWithoutCover() } }
                .disabled(store.selectedItem == nil || store.catalog?.isReadOnly == true)
            Divider()
            Button("Remove from Catalog…", role: .destructive) { store.requestBookRemoval() }
                .disabled(store.selectedItem == nil || store.catalog?.isReadOnly == true)
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

}
