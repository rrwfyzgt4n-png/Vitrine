import SwiftUI

struct LibraryGridView: View {
    @Bindable var store: CatalogStore
    @AppStorage("coverWidth") private var coverWidth = 168.0
    @AppStorage("showFileNoteSummaries") private var showFileNoteSummaries = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: coverWidth), spacing: 26)],
                alignment: .leading,
                spacing: 32
            ) {
                ForEach(store.visibleItems) { item in
                    BookCardView(
                        item: item,
                        isSelected: store.selection == item.id,
                        sourceFolderURL: store.sourceFolderURL,
                        coverWidth: coverWidth,
                        showFileNoteSummary: showFileNoteSummaries
                    )
                    .accessibilityAction(named: L10n.text("Open Cover")) {
                        store.selection = item.id
                        store.openSelectedCover()
                    }
                    .accessibilityAction(named: L10n.text("Reveal Cover in Finder")) {
                        store.selection = item.id
                        store.revealSelectedCover()
                    }
                    .onTapGesture(count: 2) {
                        store.selection = item.id
                        store.openSelectedCover()
                    }
                    .onTapGesture { store.selection = item.id }
                    .contextMenu {
                        Button("Open Cover") { store.selection = item.id; store.openSelectedCover() }
                            .disabled(item.availability != .available)
                        Button("Quick Look") { store.selection = item.id; showQuickLook() }
                            .disabled(item.availability != .available)
                        Button("Reveal Cover in Finder") { store.selection = item.id; store.revealSelectedCover() }
                            .disabled(item.availability != .available)
                        Divider()
                        Button("Suggest Details from Filename") { store.selection = item.id; store.suggestDetailsFromFilename() }
                        Button("Edit Book Details") { store.selection = item.id; store.isMetadataEditorPresented = true }
                        Button("Find Book Details Online") { store.selection = item.id; Task { await store.findBookDetailsOnline() } }
                        Divider()
                        Button("Remove from Catalog", role: .destructive) { store.selection = item.id; Task { await store.removeSelectedBook() } }
                    }
                }
            }
            .padding(28)
        }
        .focusable()
        .onKeyPress(.return) { store.openSelectedCover(); return .handled }
        .onKeyPress(.space) { showQuickLook(); return .handled }
        .onKeyPress(.leftArrow) { moveSelection(by: -1); return .handled }
        .onKeyPress(.rightArrow) { moveSelection(by: 1); return .handled }
        .onKeyPress(.upArrow) { moveSelection(by: -max(1, Int(900 / coverWidth))); return .handled }
        .onKeyPress(.downArrow) { moveSelection(by: max(1, Int(900 / coverWidth))); return .handled }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: store.selection)
    }

    private func moveSelection(by offset: Int) {
        let items = store.visibleItems
        guard !items.isEmpty else { return }
        let current = store.selection.flatMap { id in items.firstIndex(where: { $0.id == id }) } ?? 0
        store.selection = items[min(max(0, current + offset), items.count - 1)].id
    }

    private func showQuickLook() {
        if let url = store.selectedCoverURL { QuickLookService.shared.show(url: url) }
    }
}
