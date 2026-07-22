import SwiftUI

struct MetadataLookupView: View {
    @Bindable var store: CatalogStore
    @AppStorage("fallbackSearchEngine") private var fallbackSearchEngine = WebSearchEngine.duckDuckGo.rawValue
    @State private var candidateToReview: MetadataCandidate?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Find Book Details Online").font(.title2).fontWeight(.semibold)
            Form {
                TextField("ISBN (optional)", text: $store.lookupISBN)
                TextField("Confirmed title", text: $store.lookupTitle)
                TextField("Confirmed author", text: $store.lookupAuthor)
                LabeledContent("Privacy") {
                    Text("Searches only when you press Search").foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(maxHeight: 180)
            if store.isLookingUp {
                ProgressView("Searching Open Library…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.lookupCandidates.isEmpty {
                ContentUnavailableView(
                    "No Matching Details Found",
                    systemImage: "books.vertical",
                    description: Text(store.lookupMessage ?? "Try a browser search or enter details manually.")
                )
                HStack {
                    Button("Search \(preferredEngine.label)") { store.searchWeb(using: preferredEngine) }
                    Menu("Other Browser Search") {
                        ForEach(WebSearchEngine.allCases) { engine in
                            Button(engine.label) { store.searchWeb(using: engine) }
                        }
                    }
                    Button("Enter Details Manually") {
                        store.isLookupPresented = false
                        store.isMetadataEditorPresented = true
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                List(store.lookupCandidates) { candidate in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(candidate.title).font(.headline)
                        if !candidate.authors.isEmpty { Text(candidate.authors.joined(separator: ", ")).foregroundStyle(.secondary) }
                        Text([candidate.publisher, candidate.publicationDate, candidate.pageCount.map { "\($0) pages" }].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Review These Details…") { candidateToReview = candidate }
                    }
                    .padding(.vertical, 6)
                }
            }
            HStack {
                Spacer()
                Button(store.lookupCandidates.isEmpty ? "Search Open Library" : "Refresh Search") {
                    Task { await store.searchOpenLibrary(forceRefresh: !store.lookupCandidates.isEmpty) }
                }
                    .disabled(store.isLookingUp)
                Button("Close") { store.isLookupPresented = false }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 680, height: 700)
        .sheet(item: $candidateToReview) { candidate in
            if let item = store.selectedItem {
                MetadataCandidateReviewView(current: item.bibliography, candidate: candidate) {
                    await store.applyMetadataCandidate(candidate, fields: $0)
                }
            }
        }
    }

    private var preferredEngine: WebSearchEngine {
        WebSearchEngine(rawValue: fallbackSearchEngine) ?? .duckDuckGo
    }
}
