import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: CatalogStore
    @AppStorage("coverWidth") private var coverWidth = 168.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            if store.catalog == nil {
                WelcomeView(
                    isWorking: store.isPerformingCatalogOperation,
                    operationMessage: store.operationMessage,
                    createCatalog: { Task { _ = await store.createCatalog() } },
                    openCatalog: { Task { await store.openCatalog() } }
                )
            } else if store.visibleItems.isEmpty && store.searchText.isEmpty && store.filter == .all {
                EmptyLibraryView()
            } else if store.visibleItems.isEmpty && store.filter != .all {
                ContentUnavailableView {
                    Label(store.filter.label, systemImage: "line.3.horizontal.decrease.circle")
                } actions: {
                    Button(CatalogFilter.all.label) { store.filter = .all }
                }
            } else if store.visibleItems.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
            } else {
                LibraryGridView(store: store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .alert("Your catalog was edited on another Mac.", isPresented: $store.isConflictChoicePresented) {
            Button("Keep My Changes") { Task { await store.keepMyCatalogChanges() } }
            Button("Use Changes from Other Mac") { Task { await store.useChangesFromOtherMac() } }
            Button("Review Changes") { store.reviewCatalogChanges() }
            Button("Keep Browsing", role: .cancel) { store.keepBrowsingWithCatalogConflict() }
        } message: {
            Text("Some of the same information was changed in both places.")
        }
        .inspector(isPresented: $store.isInspectorPresented) {
            BookInspectorView(store: store)
                .inspectorColumnWidth(min: 320, ideal: 360, max: 420)
        }
        .sheet(isPresented: $store.isMetadataEditorPresented) {
            if let item = store.selectedItem {
                MetadataEditorView(item: item) {
                    await store.saveEditedItem($0, reason: .explicit)
                }
            }
        }
        .sheet(
            isPresented: $store.isFilenameReviewPresented,
            onDismiss: store.finishFilenameSuggestionReviewPresentation
        ) {
            if let item = store.selectedItem, let suggestion = store.filenameSuggestion {
                FilenameSuggestionReviewView(
                    filenameTitle: item.source.sourceTitle,
                    suggestion: suggestion,
                    onApply: { await store.applyFilenameSuggestion($0, to: item.id) }
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
                    restore: { backupID in Task { await store.restorePendingRecovery(backupID: backupID) } },
                    openRecovered: store.openRecoveredCatalog,
                    revealBackup: store.revealPendingRecoveryBackup,
                    revealDamaged: store.revealDamagedCatalog,
                    exportDiagnostics: store.exportRecoveryDiagnostics,
                    createNewCatalog: { Task { await store.createNewCatalogAfterRecovery() } },
                    cancel: store.cancelPendingRecovery
                )
            }
        }
        .sheet(isPresented: $store.isBackupRestorePresented) {
            CatalogBackupRestoreView(options: store.backupRestoreOptions) {
                await store.restoreBackup($0)
            }
        }
        .sheet(isPresented: $store.isCatalogHealthReportPresented) {
            if let report = store.catalogHealthReport {
                CatalogHealthReportView(report: report)
            }
        }
        .sheet(isPresented: $store.isRemovalConfirmationPresented) {
            if let item = store.pendingRemovalItem {
                BookRemovalConfirmationView(
                    item: item,
                    sourceFolderURL: store.sourceFolderURL,
                    cancel: store.cancelBookRemoval,
                    remove: store.confirmBookRemoval
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
        ToolbarItem(placement: .principal) {
            HStack(spacing: 7) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 22, height: 22)
                    .clipShape(.rect(cornerRadius: 5))
                    .accessibilityHidden(true)
                Text("Vitrine")
                    .font(.headline)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Vitrine")
        }
        .sharedBackgroundVisibility(.hidden)

        if let catalog = store.catalog {
            ToolbarItem(placement: .navigation) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(catalog.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(L10n.bookCount(store.visibleItems.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
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
                } label: {
                    Label(store.filter == .all ? L10n.text("Sort and Filter") : store.filter.label,
                          systemImage: store.filter == .all
                              ? "line.3.horizontal.decrease"
                              : "line.3.horizontal.decrease.circle.fill")
                }
                .labelStyle(.iconOnly)
                .help(store.filter == .all ? L10n.text("Sort and Filter") : store.filter.label)
                .buttonStyle(.glass)

                ControlGroup {
                    Button {
                        stepCoverSize(by: -12)
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                            .foregroundStyle(.primary.opacity(decreaseCoverEmphasis))
                    }
                    .help("Decrease Cover Size")

                    Button {
                        stepCoverSize(by: 12)
                    } label: {
                        Image(systemName: "textformat.size.larger")
                            .foregroundStyle(.primary.opacity(increaseCoverEmphasis))
                    }
                    .help("Increase Cover Size")
                }
                .controlSize(.small)
                .buttonStyle(.glass)
                .accessibilityLabel("Cover size")
                .accessibilityValue(Int(coverWidth).formatted())
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItemGroup(placement: .primaryAction) {
                Button("Refresh Covers", systemImage: "arrow.clockwise") { Task { await store.refreshCovers() } }
                    .labelStyle(.iconOnly)
                    .help("Refresh Covers")
                    .buttonStyle(.glass)
                    .disabled(!store.canRefreshCovers)
                    .accessibilityIdentifier("toolbar.refresh")
                Button("Inspector", systemImage: "sidebar.trailing") { store.showInspector() }
                    .labelStyle(.iconOnly)
                    .help(store.isInspectorPresented ? "Hide Inspector" : "Show Inspector")
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("toolbar.inspector")
            }
        }
    }

    private var coverSizeProgress: Double {
        min(1, max(0, (coverWidth - 120) / (260 - 120)))
    }

    private var decreaseCoverEmphasis: Double {
        0.38 + ((1 - coverSizeProgress) * 0.62)
    }

    private var increaseCoverEmphasis: Double {
        0.38 + (coverSizeProgress * 0.62)
    }

    private func stepCoverSize(by amount: Double) {
        let update = {
            coverWidth = min(260, max(120, coverWidth + amount))
        }
        if reduceMotion {
            update()
        } else {
            withAnimation(.snappy(duration: 0.16), update)
        }
    }
}
