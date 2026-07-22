import SwiftUI

struct MetadataCandidateReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let current: BibliographicMetadata
    let candidate: MetadataCandidate
    let onApply: (Set<MetadataCandidateField>) async -> Void
    @State private var selected: Set<MetadataCandidateField>

    init(
        current: BibliographicMetadata,
        candidate: MetadataCandidate,
        onApply: @escaping (Set<MetadataCandidateField>) async -> Void
    ) {
        self.current = current
        self.candidate = candidate
        self.onApply = onApply
        _selected = State(initialValue: Self.defaultSelection(current: current, candidate: candidate))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compare Book Details").font(.title2).fontWeight(.semibold)
            Text("Existing values are kept unless you select the Open Library value.")
                .foregroundStyle(.secondary)
            List {
                comparison("Book Title", field: .title, existing: current.title, proposed: candidate.title)
                comparison("Subtitle", field: .subtitle, existing: current.subtitle, proposed: candidate.subtitle)
                comparison("Authors", field: .authors, existing: joined(current.authors), proposed: joined(candidate.authors))
                comparison("Publisher", field: .publisher, existing: current.publisher, proposed: candidate.publisher)
                comparison("Published", field: .publicationDate, existing: current.publicationDate, proposed: candidate.publicationDate)
                comparison("Originally Published", field: .originalPublicationDate, existing: current.originalPublicationDate, proposed: candidate.originalPublicationDate)
                comparison("Pages", field: .pageCount, existing: current.pageCount.map(String.init), proposed: candidate.pageCount.map(String.init))
                comparison("Language", field: .language, existing: current.languageCode, proposed: candidate.languageCodes.first)
                comparison("Subjects", field: .subjects, existing: joined(current.subjects), proposed: joined(candidate.subjects))
                comparison("ISBN-10", field: .isbn10, existing: current.isbn10, proposed: candidate.isbn10)
                comparison("ISBN-13", field: .isbn13, existing: current.isbn13, proposed: candidate.isbn13)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply Selected Fields") {
                    let acceptedFields = selected
                    dismiss()
                    Task { await onApply(acceptedFields) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 720, height: 700)
    }

    @ViewBuilder
    private func comparison(_ label: LocalizedStringKey, field: MetadataCandidateField, existing: String?, proposed: String?) -> some View {
        if let proposed, !proposed.isEmpty {
            Toggle(isOn: binding(for: field)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.headline)
                    LabeledContent("Current", value: existing.flatMap { $0.isEmpty ? nil : $0 } ?? "Empty")
                    LabeledContent("Open Library", value: proposed)
                }
            }
            .padding(.vertical, 5)
        }
    }

    private func binding(for field: MetadataCandidateField) -> Binding<Bool> {
        Binding(
            get: { selected.contains(field) },
            set: { if $0 { selected.insert(field) } else { selected.remove(field) } }
        )
    }

    private func joined(_ values: [String]) -> String? {
        values.isEmpty ? nil : values.joined(separator: ", ")
    }

    private static func defaultSelection(
        current: BibliographicMetadata,
        candidate: MetadataCandidate
    ) -> Set<MetadataCandidateField> {
        var result: Set<MetadataCandidateField> = []
        if current.title?.isEmpty != false { result.insert(.title) }
        if current.subtitle?.isEmpty != false, candidate.subtitle != nil { result.insert(.subtitle) }
        if current.authors.isEmpty, !candidate.authors.isEmpty { result.insert(.authors) }
        if current.publisher?.isEmpty != false, candidate.publisher != nil { result.insert(.publisher) }
        if current.publicationDate?.isEmpty != false, candidate.publicationDate != nil { result.insert(.publicationDate) }
        if current.originalPublicationDate?.isEmpty != false, candidate.originalPublicationDate != nil { result.insert(.originalPublicationDate) }
        if current.pageCount == nil, candidate.pageCount != nil { result.insert(.pageCount) }
        if current.languageCode == nil, !candidate.languageCodes.isEmpty { result.insert(.language) }
        if current.subjects.isEmpty, !candidate.subjects.isEmpty { result.insert(.subjects) }
        if current.isbn10 == nil, candidate.isbn10 != nil { result.insert(.isbn10) }
        if current.isbn13 == nil, candidate.isbn13 != nil { result.insert(.isbn13) }
        return result
    }
}
