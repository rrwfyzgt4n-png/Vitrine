import SwiftUI

struct LibraryGridView: View {
    @Bindable var store: CatalogStore
    @AppStorage("coverWidth") private var coverWidth = 168.0
    @AppStorage("showFileNoteSummaries") private var showFileNoteSummaries = true
    @FocusState private var gridHasKeyboardFocus: Bool

    var body: some View {
        let items = store.visibleItems

        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: coverWidth), spacing: 26)],
                    alignment: .leading,
                    spacing: 32
                ) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        BookCardView(
                            item: item,
                            isSelected: store.selection == item.id,
                            sourceFolderURL: store.sourceFolderURL,
                            coverWidth: coverWidth,
                            showFileNoteSummary: showFileNoteSummaries,
                            gridPosition: index + 1,
                            gridCount: items.count,
                            hasKeyboardFocus: gridHasKeyboardFocus
                        )
                        .accessibilityAction(named: L10n.text("Open Cover")) {
                            store.selection = item.id
                            store.openSelectedCover()
                        }
                        .accessibilityAction(named: L10n.text("Reveal Cover in Finder")) {
                            store.selection = item.id
                            store.revealSelectedCover()
                        }
                        .accessibilityAction(named: L10n.text("Quick Look")) {
                            store.selection = item.id
                            showQuickLook()
                        }
                        .accessibilityAction(named: L10n.text("Edit Book Details")) {
                            guard store.catalog?.isReadOnly != true else { return }
                            store.selection = item.id
                            store.isMetadataEditorPresented = true
                        }
                        .accessibilityAction(named: L10n.text("Suggest Details from Filename")) {
                            guard store.catalog?.isReadOnly != true else { return }
                            store.selection = item.id
                            store.suggestDetailsFromFilename()
                        }
                        .onTapGesture(count: 2) {
                            store.selection = item.id
                            store.openSelectedCover()
                        }
                        .onTapGesture {
                            store.selection = item.id
                            gridHasKeyboardFocus = true
                        }
                        .contextMenu {
                            Button("Open Cover") { store.selection = item.id; store.openSelectedCover() }
                                .disabled(item.availability != .available)
                            Button("Quick Look") { store.selection = item.id; showQuickLook() }
                                .disabled(item.availability != .available)
                            Button("Reveal Cover in Finder") { store.selection = item.id; store.revealSelectedCover() }
                                .disabled(item.availability != .available)
                            Divider()
                            Button("Suggest Details from Filename") { store.selection = item.id; store.suggestDetailsFromFilename() }
                                .disabled(store.catalog?.isReadOnly == true)
                            Button("Edit Book Details") { store.selection = item.id; store.isMetadataEditorPresented = true }
                                .disabled(store.catalog?.isReadOnly == true)
                            Button("Find Book Details Online") { store.selection = item.id; Task { await store.findBookDetailsOnline() } }
                                .disabled(store.catalog?.isReadOnly == true)
                            Divider()
                            Button("Remove from Catalog…", role: .destructive) {
                                store.selection = item.id
                                store.requestBookRemoval(itemID: item.id)
                            }
                            .disabled(store.catalog?.isReadOnly == true)
                        }
                        .id(item.id)
                    }
                }
                .padding(28)
            }
            .focusable()
            .focused($gridHasKeyboardFocus)
            .focusEffectDisabled()
            .accessibilityIdentifier("library.grid")
            .accessibilityLabel("Book grid")
            .onKeyPress(.return) { store.openSelectedCover(); return .handled }
            .onKeyPress(.space) { showQuickLook(); return .handled }
            .onKeyPress(.leftArrow) { moveSelection(by: -1, in: items, proxy: proxy); return .handled }
            .onKeyPress(.rightArrow) { moveSelection(by: 1, in: items, proxy: proxy); return .handled }
            .onKeyPress(.upArrow) { moveSelection(by: -max(1, Int(900 / coverWidth)), in: items, proxy: proxy); return .handled }
            .onKeyPress(.downArrow) { moveSelection(by: max(1, Int(900 / coverWidth)), in: items, proxy: proxy); return .handled }
            .onKeyPress(.home) { moveSelection(to: items.first?.id, proxy: proxy); return .handled }
            .onKeyPress(.end) { moveSelection(to: items.last?.id, proxy: proxy); return .handled }
        }
    }

    private func moveSelection(by offset: Int, in items: [CatalogItem], proxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }
        let current = store.selection.flatMap { id in items.firstIndex(where: { $0.id == id }) } ?? 0
        moveSelection(to: items[min(max(0, current + offset), items.count - 1)].id, proxy: proxy)
    }

    private func moveSelection(to itemID: UUID?, proxy: ScrollViewProxy) {
        guard let itemID else { return }
        store.selection = itemID
        proxy.scrollTo(itemID, anchor: .center)
    }

    private func showQuickLook() {
        store.quickLookSelectedCover()
    }
}
