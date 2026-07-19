import SwiftUI

struct BookInspectorView: View {
    @Bindable var store: CatalogStore
    @AppStorage("bookDetailsExpanded") private var bookDetailsExpanded = false
    @AppStorage("fileInformationExpanded") private var fileInformationExpanded = false

    var body: some View {
        if let item = store.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CoverPreviewView(item: item, sourceFolderURL: store.sourceFolderURL)
                    Text(item.displayTitle).font(.title2).fontWeight(.semibold)
                    if let author = item.displayAuthor { Text(author).foregroundStyle(.secondary) }
                    if !item.personalNotes.isEmpty { Text(item.personalNotes) }
                    HStack {
                        Button("Edit") { store.isMetadataEditorPresented = true }
                        Button("Suggest from Filename") { store.suggestDetailsFromFilename() }
                    }
                    DisclosureGroup("Book Details", isExpanded: $bookDetailsExpanded) {
                        BookDetailsSection(item: item)
                        HStack {
                            Button("Find Book Details Online") { Task { await store.findBookDetailsOnline() } }
                            if item.bibliography.metadataSource != nil {
                                Button("Refresh") { Task { await store.findBookDetailsOnline(forceRefresh: true) } }
                                Button("Remove Added Book Details", role: .destructive) {
                                    Task { await store.removeSelectedBookDetails() }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    DisclosureGroup("File Information", isExpanded: $fileInformationExpanded) {
                        FileInformationSection(item: item)
                    }
                    if item.availability != .available {
                        HStack {
                            if item.availability == .ambiguousMatch,
                               store.ambiguousCandidates[item.id]?.isEmpty == false {
                                Button("Review Matches…") { store.isAmbiguousReviewPresented = true }
                            }
                            Button("Locate Cover Folder…") { Task { await store.locateCoverFolder() } }
                            if store.sourceFolderURL != nil {
                                Button("Choose Replacement Cover…") { Task { await store.chooseReplacementCover() } }
                            }
                            Button("Keep Without Cover") { Task { await store.keepSelectedWithoutCover() } }
                            Button("Remove from Catalog", role: .destructive) { Task { await store.removeSelectedBook() } }
                        }
                    }
                }
                .padding()
            }
        } else {
            ContentUnavailableView("No Book Selected", systemImage: "book.closed")
        }
    }
}
