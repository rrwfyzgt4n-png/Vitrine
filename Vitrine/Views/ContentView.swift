import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: CatalogStore
    @AppStorage("coverWidth") private var coverWidth = 168.0
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            if store.catalog == nil {
                WelcomeView(
                    isWorking: store.isPerformingCatalogOperation,
                    operationMessage: store.operationMessage,
                    createCatalog: { Task { await store.createCatalog() } },
                    openCatalog: { Task { await store.openCatalog() } }
                )
            } else if store.visibleItems.isEmpty && store.searchText.isEmpty && store.filter == .all {
                EmptyLibraryView()
            } else if store.visibleItems.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            } else {
                LibraryGridView(store: store)
            }
        }
        .searchable(text: $store.searchText, prompt: "Search your library")
        .searchFocused($searchFocused)
        .overlay(alignment: .bottom) {
            if let message = store.operationMessage ?? store.statusMessage {
                FloatingStatusView(
                    message: message,
                    locate: store.isBrowsingWithoutCovers ? { Task { await store.locateCoverFolder() } } : nil,
                    cancel: store.canCancelOperation ? { store.cancelCurrentOperation() } : nil
                )
                .padding(.bottom, 18)
            } else if store.isBrowsingWithoutCovers {
                FloatingStatusView(
                    message: L10n.text("Covers unavailable — folder not found"),
                    locate: { Task { await store.locateCoverFolder() } }
                )
                .padding(.bottom, 18)
            }
        }
        .alert(
            "Vitrine Couldn't Complete That Action",
            isPresented: Binding(
                get: { store.presentedError != nil },
                set: { if !$0 { store.presentedError = nil } }
            )
        ) {
            Button("OK") { store.presentedError = nil }
        } message: {
            Text(store.presentedError?.localizedDescription ?? "Please try again.")
        }
        .alert("This folder doesn't seem to match your catalog. Are you sure?", isPresented: $store.isWrongFolderConfirmationPresented) {
            Button("Choose Another Folder") {
                store.pendingMismatchedFolderURL = nil
                Task { await store.locateCoverFolder() }
            }
            Button("Use This Folder") { Task { await store.usePendingMismatchedFolder() } }
            Button("Cancel", role: .cancel) { store.pendingMismatchedFolderURL = nil }
        } message: {
            Text("Vitrine found few or no matching covers. Using it may add a different collection to this catalog.")
        }
        .inspector(isPresented: $store.isInspectorPresented) {
            BookInspectorView(store: store)
                .inspectorColumnWidth(min: 320, ideal: 360, max: 420)
        }
        .sheet(isPresented: $store.isMetadataEditorPresented) {
            if let item = store.selectedItem {
                MetadataEditorView(item: item) { await store.saveEditedItem($0) }
            }
        }
        .sheet(isPresented: $store.isFilenameReviewPresented) {
            if let item = store.selectedItem, let suggestion = store.filenameSuggestion {
                FilenameSuggestionReviewView(
                    filenameTitle: item.source.sourceTitle,
                    suggestion: suggestion,
                    onApply: { await store.applyFilenameSuggestion($0) }
                )
            }
        }
        .sheet(isPresented: $store.isLookupPresented) {
            MetadataLookupView(store: store)
        }
        .sheet(isPresented: $store.isConflictReviewPresented) {
            if let pending = store.pendingCatalogMerge {
                CatalogConflictReviewView(pending: pending) {
                    await store.resolveCatalogConflicts(useExternal: $0)
                }
            }
        }
        .sheet(isPresented: $store.isAmbiguousReviewPresented) {
            if let item = store.selectedItem,
               let candidates = store.ambiguousCandidates[item.id] {
                AmbiguousMatchReviewView(item: item, candidates: candidates) {
                    await store.associateSelectedCover(relativePath: $0)
                }
            }
        }
        .sheet(isPresented: $store.isRecoveryPresented) {
            if let recovery = store.pendingRecovery {
                CatalogRecoveryView(
                    recovery: recovery,
                    restore: { Task { await store.restorePendingRecovery() } },
                    revealBackup: store.revealPendingRecoveryBackup,
                    cancel: store.cancelPendingRecovery
                )
            }
        }
        .toolbar { toolbarContent }
        .task { await store.start() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await store.applicationBecameActive() }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didMountNotification)) { _ in
            Task { await store.mountedVolumesChanged() }
        }
        .onChange(of: store.focusSearchRequest) { _, _ in searchFocused = true }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if let catalog = store.catalog {
            ToolbarItem(placement: .navigation) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(catalog.name).font(.headline)
                    Text(L10n.bookCount(store.visibleItems.count)).font(.caption).foregroundStyle(.secondary)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Menu("Sort and Filter", systemImage: "line.3.horizontal.decrease.circle") {
                    Section("Sort") {
                        Picker("Sort", selection: $store.sortOption) {
                            ForEach(CatalogSortOption.allCases) { Text($0.label).tag($0) }
                        }
                    }
                    Section("Filter") {
                        Picker("Filter", selection: $store.filter) {
                            ForEach(CatalogFilter.allCases) { Text($0.label).tag($0) }
                        }
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "textformat.size.smaller")
                    Slider(value: $coverWidth, in: 120...260, step: 4).frame(width: 100)
                    Image(systemName: "textformat.size.larger")
                }
                .accessibilityLabel("Cover size")
                Button("Refresh Covers", systemImage: "arrow.clockwise") { Task { await store.refreshCovers() } }
                    .help("Refresh Covers")
                    .disabled(!store.canRefreshCovers)
                Button("Inspector", systemImage: "sidebar.trailing") { store.showInspector() }
                    .help(store.isInspectorPresented ? "Hide Inspector" : "Show Inspector")
            }
        }
    }
}
