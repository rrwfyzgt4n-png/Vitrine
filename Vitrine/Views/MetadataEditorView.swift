import SwiftUI

struct MetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: CatalogItem
    let onSave: (CatalogItem) async -> Void

    init(item: CatalogItem, onSave: @escaping (CatalogItem) async -> Void) {
        _item = State(initialValue: item)
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Book Details") {
                    TextField("Book Title", text: optional(\.bibliography.title))
                    TextField("Subtitle", text: optional(\.bibliography.subtitle))
                    TextField("Authors (comma separated)", text: authors)
                    TextField("Translators (comma separated)", text: translators)
                    TextField("Contributors (name | roles; …)", text: contributors)
                    TextField("Publisher", text: optional(\.bibliography.publisher))
                    TextField("Collection", text: optional(\.bibliography.collectionName))
                    TextField("Collection number", text: optional(\.bibliography.collectionNumber))
                    TextField("Publication place", text: optional(\.bibliography.publicationPlace))
                    TextField("Publication date", text: optional(\.bibliography.publicationDate))
                    TextField("Original publication date", text: optional(\.bibliography.originalPublicationDate))
                    TextField("Edition", text: optional(\.bibliography.editionDescription))
                    TextField("Volume or part", text: optional(\.bibliography.volumeDescription))
                    TextField("Language", text: optional(\.bibliography.languageCode))
                    TextField("Additional languages (comma separated)", text: additionalLanguages)
                    TextField("Original language", text: optional(\.bibliography.originalLanguageCode))
                    TextField("Pages", text: pages)
                    TextField("Pagination", text: pagination)
                    TextField("Physical attributes (comma separated)", text: physicalAttributes)
                    TextField("ISBN-10", text: optional(\.bibliography.isbn10))
                    TextField("ISBN-13", text: optional(\.bibliography.isbn13))
                    TextField("Subjects (comma separated)", text: subjects)
                    TextField("Description", text: optional(\.bibliography.description), axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Personal Notes") {
                    TextEditor(text: $item.personalNotes).frame(minHeight: 100)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    item.bibliography.metadataSource = .manual
                    item.bibliography.metadataConfirmedByUser = true
                    let editedItem = item
                    dismiss()
                    Task { await onSave(editedItem) }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 620, height: 720)
    }

    private func optional(_ keyPath: WritableKeyPath<CatalogItem, String?>) -> Binding<String> {
        Binding(
            get: { item[keyPath: keyPath] ?? "" },
            set: { item[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private var authors: Binding<String> {
        list(\.bibliography.authors)
    }

    private var translators: Binding<String> {
        list(\.bibliography.translators)
    }

    private var subjects: Binding<String> {
        list(\.bibliography.subjects)
    }

    private var additionalLanguages: Binding<String> {
        list(\.bibliography.additionalLanguageCodes)
    }

    private var contributors: Binding<String> {
        Binding(
            get: {
                item.bibliography.contributors.map {
                    "\($0.name) | \($0.roles.map(\.rawValue).joined(separator: ","))"
                }.joined(separator: "; ")
            },
            set: { value in
                item.bibliography.contributors = value.split(separator: ";").compactMap { entry in
                    let parts = entry.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    guard parts.count == 2 else { return nil }
                    let roles = parts[1].split(separator: ",").compactMap {
                        ContributorRole(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    guard !parts[0].isEmpty, !roles.isEmpty else { return nil }
                    return BibliographicContributor(name: parts[0], roles: roles)
                }
            }
        )
    }

    private var pagination: Binding<String> {
        Binding(
            get: { item.bibliography.paginationStatus?.rawValue ?? "" },
            set: { item.bibliography.paginationStatus = PaginationStatus(rawValue: $0) }
        )
    }

    private var physicalAttributes: Binding<String> {
        Binding(
            get: { item.bibliography.physicalAttributes.map(\.rawValue).joined(separator: ", ") },
            set: { value in
                item.bibliography.physicalAttributes = value.split(separator: ",").compactMap {
                    PhysicalAttribute(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        )
    }

    private func list(_ keyPath: WritableKeyPath<CatalogItem, [String]>) -> Binding<String> {
        Binding(
            get: { item[keyPath: keyPath].joined(separator: ", ") },
            set: { item[keyPath: keyPath] = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }

    private var pages: Binding<String> {
        Binding(
            get: { item.bibliography.pageCount.map(String.init) ?? "" },
            set: { item.bibliography.pageCount = Int($0) }
        )
    }
}
