import SwiftUI

struct MetadataLookupView: View {
    @Bindable var store: CatalogStore
    @AppStorage("fallbackSearchEngine") private var fallbackSearchEngine = WebSearchEngine.duckDuckGo.rawValue
    @State private var candidateToReview: MetadataCandidate?
    @State private var hasStartedInitialLookup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Find Book Details Online", systemImage: "books.vertical")
                .font(.title2.bold())

            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 11) {
                    queryRow("ISBN (optional)", text: $store.lookupISBN)
                    queryRow("Confirmed title", text: $store.lookupTitle)
                    queryRow("Confirmed author", text: $store.lookupAuthor)

                    Divider()
                        .gridCellColumns(2)

                    GridRow(alignment: .firstTextBaseline) {
                        Label("Privacy", systemImage: "hand.raised")
                            .foregroundStyle(.secondary)
                            .frame(width: 132, alignment: .leading)
                        Text("Vitrine only contacts Open Library when you explicitly start a search.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(4)
            }

            resultContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack(spacing: 8) {
                Spacer()
                Button("Close") { store.isLookupPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(store.lookupCandidates.isEmpty ? "Search Open Library" : "Refresh Search",
                       systemImage: "magnifyingglass") {
                    Task { await store.searchOpenLibrary(forceRefresh: !store.lookupCandidates.isEmpty) }
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(store.isLookingUp)
            }
            .buttonStyle(.glass)
        }
        .padding(24)
        .frame(width: 720, height: 620)
        .task {
            hasStartedInitialLookup = true
            await store.prefetchOpenLibraryIfNeeded()
        }
        .sheet(item: $candidateToReview) { candidate in
            if let item = store.selectedItem {
                MetadataCandidateReviewView(current: item.bibliography, candidate: candidate) {
                    await store.applyMetadataCandidate(candidate, fields: $0)
                }
            }
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if !hasStartedInitialLookup || store.isLookingUp {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.regular)
                Text("Searching Open Library…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        } else if store.lookupCandidates.isEmpty {
            ContentUnavailableView {
                Label("No Matching Details Found", systemImage: "books.vertical")
            } description: {
                Text(store.lookupMessage ?? "Try a browser search or enter details manually.")
            } actions: {
                HStack(spacing: 8) {
                    Button("Search \(preferredEngine.label)", systemImage: "safari") {
                        store.searchWeb(using: preferredEngine)
                    }
                    Menu("Other Browser Search", systemImage: "ellipsis.circle") {
                        ForEach(WebSearchEngine.allCases) { engine in
                            Button(engine.label) { store.searchWeb(using: engine) }
                        }
                    }
                    Button("Enter Details Manually", systemImage: "square.and.pencil") {
                        store.isLookupPresented = false
                        store.isMetadataEditorPresented = true
                    }
                }
                .buttonStyle(.glass)
            }
        } else {
            List(store.lookupCandidates) { candidate in
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(candidate.title)
                            .font(.headline)
                            .lineLimit(2)
                        if !candidate.authors.isEmpty {
                            Text(candidate.authors.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if !candidateSummary(candidate).isEmpty {
                            Text(candidateSummary(candidate))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 12)
                    Button("Review These Details…", systemImage: "checklist") {
                        candidateToReview = candidate
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
                .padding(.vertical, 7)
            }
            .listStyle(.inset)
        }
    }

    private func queryRow(_ label: LocalizedStringKey, text: Binding<String>) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 132, alignment: .leading)
            TextField(text: text) {
                Text(label)
            }
            .labelsHidden()
        }
    }

    private func candidateSummary(_ candidate: MetadataCandidate) -> String {
        [
            candidate.publisher,
            candidate.publicationDate,
            candidate.pageCount.map { "\($0) pages" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var preferredEngine: WebSearchEngine {
        WebSearchEngine(rawValue: fallbackSearchEngine) ?? .duckDuckGo
    }
}
