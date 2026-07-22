import SwiftUI

struct BookInspectorView: View {
    @Bindable var store: CatalogStore
    @AppStorage("bookDetailsExpanded") private var bookDetailsExpanded = false
    @AppStorage("fileInformationExpanded") private var fileInformationExpanded = false

    var body: some View {
        if let item = store.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CoverPreviewView(item: item, sourceFolderURL: store.sourceFolderURL)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(item.displayTitle)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)
                        if let author = item.displayAuthor {
                            Text(author)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        if !item.personalNotes.isEmpty {
                            Text(item.personalNotes)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(.top, 3)
                        }
                    }

                    primaryActions
                        .disabled(store.catalog?.isReadOnly != false)

                    Divider()

                    DisclosureGroup(isExpanded: $bookDetailsExpanded) {
                        BookDetailsSection(item: item)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { bookDetailActions(for: item) }
                            VStack(alignment: .leading, spacing: 8) { bookDetailActions(for: item) }
                        }
                        .controlSize(.small)
                        .buttonStyle(.glass)
                        .padding(.top, 10)
                        .disabled(store.catalog?.isReadOnly == true)
                    } label: {
                        Text("Book Details")
                            .font(.headline)
                    }
                    .accessibilityIdentifier("inspector.bookDetails")

                    Divider()

                    DisclosureGroup(isExpanded: $fileInformationExpanded) {
                        FileInformationSection(item: item)
                    } label: {
                        Text("File Information")
                            .font(.headline)
                    }
                    .accessibilityIdentifier("inspector.fileInformation")

                    if item.availability != .available {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            if item.availability == .ambiguousMatch,
                               store.ambiguousCandidates[item.id]?.isEmpty == false {
                                Button("Review Matches…", systemImage: "rectangle.stack.badge.questionmark") {
                                    store.isAmbiguousReviewPresented = true
                                }
                            }
                            Button("Locate Cover Folder…", systemImage: "folder.badge.questionmark") {
                                Task { await store.locateCoverFolder() }
                            }
                            if store.sourceFolderURL != nil {
                                Button("Choose Replacement Cover…", systemImage: "photo.badge.plus") {
                                    Task { await store.chooseReplacementCover() }
                                }
                            }
                            Button("Keep Without Cover", systemImage: "book.closed") {
                                Task { await store.keepSelectedWithoutCover() }
                            }
                            Button("Remove from Catalog…", systemImage: "trash", role: .destructive) {
                                store.requestBookRemoval(itemID: item.id)
                            }
                        }
                        .controlSize(.small)
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .onChange(of: store.bookDetailsExpansionRequest) { _, _ in
                bookDetailsExpanded = true
            }
        } else {
            ContentUnavailableView("No Book Selected", systemImage: "book.closed")
        }
    }

    private var primaryActions: some View {
        GlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    primaryActionButtons
                }
                VStack(alignment: .leading, spacing: 8) {
                    primaryActionButtons
                }
            }
        }
        .controlSize(.small)
        .buttonStyle(.glass)
    }

    @ViewBuilder
    private var primaryActionButtons: some View {
        Button("Edit", systemImage: "pencil") {
            store.isMetadataEditorPresented = true
        }
        .accessibilityIdentifier("inspector.edit")

        Button("Suggest from Filename", systemImage: "text.magnifyingglass") {
            store.suggestDetailsFromFilename()
        }
    }

    @ViewBuilder
    private func bookDetailActions(for item: CatalogItem) -> some View {
        Button("Find Book Details Online", systemImage: "magnifyingglass") {
            Task { await store.findBookDetailsOnline() }
        }
        if item.bibliography.metadataSource != nil {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await store.findBookDetailsOnline(forceRefresh: true) }
            }
            Button("Remove Added Book Details", systemImage: "minus.circle", role: .destructive) {
                Task { await store.removeSelectedBookDetails() }
            }
        }
    }
}
