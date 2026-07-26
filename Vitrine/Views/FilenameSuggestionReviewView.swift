import SwiftUI

struct FilenameSuggestionReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var suggestion: FilenameMetadataSuggestion
    @State private var includeTitle = true
    @State private var includeSubtitle = true
    @State private var includeAuthors = true
    @State private var includeTranslators = true
    @State private var includeContributors = true
    @State private var includePublisher = true
    @State private var includeCollection = true
    @State private var includeCollectionNumber = true
    @State private var includePublicationPlace = true
    @State private var includePublication = true
    @State private var includeOriginalPublication = true
    @State private var includeEdition = true
    @State private var includeVolume = true
    @State private var includeLanguages = true
    @State private var includeOriginalLanguage = true
    @State private var includePages = true
    @State private var includePagination = true
    @State private var includePhysicalAttributes = true
    @State private var includeNotes = true
    @State private var titleText: String
    @State private var subtitleText: String
    @State private var authorsText: String
    @State private var translatorsText: String
    @State private var contributorsText: String
    @State private var publisherText: String
    @State private var collectionText: String
    @State private var collectionNumberText: String
    @State private var publicationPlaceText: String
    @State private var publicationText: String
    @State private var originalPublicationText: String
    @State private var editionText: String
    @State private var volumeText: String
    @State private var languagesText: String
    @State private var originalLanguageText: String
    @State private var pagesText: String
    @State private var paginationText: String
    @State private var physicalAttributesText: String
    @State private var notesText: String
    @State private var isApplying = false
    let filenameTitle: String
    let onApply: (FilenameMetadataSuggestion) async -> Bool

    init(filenameTitle: String, suggestion: FilenameMetadataSuggestion, onApply: @escaping (FilenameMetadataSuggestion) async -> Bool) {
        self.filenameTitle = filenameTitle
        _suggestion = State(initialValue: suggestion)
        _titleText = State(initialValue: suggestion.title?.value ?? "")
        _subtitleText = State(initialValue: suggestion.subtitle?.value ?? "")
        _authorsText = State(initialValue: suggestion.authors?.value.joined(separator: ", ") ?? "")
        _translatorsText = State(initialValue: suggestion.translators?.value.joined(separator: ", ") ?? "")
        _contributorsText = State(initialValue: Self.contributorText(for: suggestion.contributors?.value ?? []))
        _publisherText = State(initialValue: suggestion.publisher?.value ?? "")
        _collectionText = State(initialValue: suggestion.collectionName?.value ?? "")
        _collectionNumberText = State(initialValue: suggestion.collectionNumber?.value ?? "")
        _publicationPlaceText = State(initialValue: suggestion.publicationPlace?.value ?? "")
        _publicationText = State(initialValue: suggestion.publicationDate?.value ?? "")
        _originalPublicationText = State(initialValue: suggestion.originalPublicationDate?.value ?? "")
        _editionText = State(initialValue: suggestion.editionDescription?.value ?? "")
        _volumeText = State(initialValue: suggestion.volumeDescription?.value ?? "")
        _languagesText = State(initialValue: suggestion.languageCodes?.value.joined(separator: ", ") ?? "")
        _originalLanguageText = State(initialValue: suggestion.originalLanguageCode?.value ?? "")
        _pagesText = State(initialValue: suggestion.pageCount.map { String($0.value) } ?? "")
        _paginationText = State(initialValue: suggestion.paginationStatus?.value.label ?? "")
        _physicalAttributesText = State(initialValue: suggestion.physicalAttributes?.value.map(\.label).joined(separator: ", ") ?? "")
        _notesText = State(initialValue: suggestion.descriptiveNotes?.value ?? "")
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Suggestions from Filename", systemImage: "text.magnifyingglass")
                    .font(.title2.bold())
                Text(filenameTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    suggestionRow("Book Title", enabled: $includeTitle, value: $titleText, suggestion: suggestion.title)
                    suggestionRow("Subtitle", enabled: $includeSubtitle, value: $subtitleText, suggestion: suggestion.subtitle)
                    suggestionRow("Authors", enabled: $includeAuthors, value: $authorsText, suggestion: suggestion.authors)
                    suggestionRow("Translators", enabled: $includeTranslators, value: $translatorsText, suggestion: suggestion.translators)
                    suggestionRow("Contributors", enabled: $includeContributors, value: $contributorsText, suggestion: suggestion.contributors)
                    suggestionRow("Publisher", enabled: $includePublisher, value: $publisherText, suggestion: suggestion.publisher)
                    suggestionRow("Collection", enabled: $includeCollection, value: $collectionText, suggestion: suggestion.collectionName)
                    suggestionRow("Collection Number", enabled: $includeCollectionNumber, value: $collectionNumberText, suggestion: suggestion.collectionNumber)
                    suggestionRow("Publication Place", enabled: $includePublicationPlace, value: $publicationPlaceText, suggestion: suggestion.publicationPlace)
                    suggestionRow("Published", enabled: $includePublication, value: $publicationText, suggestion: suggestion.publicationDate)
                    suggestionRow("Originally Published", enabled: $includeOriginalPublication, value: $originalPublicationText, suggestion: suggestion.originalPublicationDate)
                    suggestionRow("Edition", enabled: $includeEdition, value: $editionText, suggestion: suggestion.editionDescription)
                    suggestionRow("Volume or Part", enabled: $includeVolume, value: $volumeText, suggestion: suggestion.volumeDescription)
                    suggestionRow("Languages", enabled: $includeLanguages, value: $languagesText, suggestion: suggestion.languageCodes)
                    suggestionRow("Original Language", enabled: $includeOriginalLanguage, value: $originalLanguageText, suggestion: suggestion.originalLanguageCode)
                    suggestionRow("Pages", enabled: $includePages, value: $pagesText, suggestion: suggestion.pageCount)
                    suggestionRow("Pagination", enabled: $includePagination, value: $paginationText, suggestion: suggestion.paginationStatus)
                    suggestionRow("Physical Attributes", enabled: $includePhysicalAttributes, value: $physicalAttributesText, suggestion: suggestion.physicalAttributes)
                    suggestionRow("Description", enabled: $includeNotes, value: $notesText, suggestion: suggestion.descriptiveNotes)

                    if !availableFields.isEmpty {
                        HStack {
                            Menu {
                                ForEach(availableFields) { field in
                                    Button {
                                        add(field)
                                    } label: {
                                        Label(field.label, systemImage: field.systemImage)
                                    }
                                }
                            } label: {
                                Label("Add Field", systemImage: "plus")
                            }
                            .menuStyle(.button)
                            .buttonStyle(.glass)

                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(.quinary, in: .rect(cornerRadius: 12))
            .clipShape(.rect(cornerRadius: 12))

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isApplying)
                Button("Apply Selected") {
                    suggestion.title = includeTitle ? updated(suggestion.title, value: titleText) : nil
                    suggestion.subtitle = includeSubtitle ? updated(suggestion.subtitle, value: subtitleText) : nil
                    suggestion.authors = includeAuthors ? updated(suggestion.authors, value: list(from: authorsText)) : nil
                    suggestion.translators = includeTranslators ? updated(suggestion.translators, value: list(from: translatorsText)) : nil
                    suggestion.contributors = includeContributors ? updated(suggestion.contributors, value: contributors(from: contributorsText)) : nil
                    suggestion.publisher = includePublisher ? updated(suggestion.publisher, value: publisherText) : nil
                    suggestion.collectionName = includeCollection ? updated(suggestion.collectionName, value: collectionText) : nil
                    suggestion.collectionNumber = includeCollectionNumber ? updated(suggestion.collectionNumber, value: collectionNumberText) : nil
                    suggestion.publicationPlace = includePublicationPlace ? updated(suggestion.publicationPlace, value: publicationPlaceText) : nil
                    suggestion.publicationDate = includePublication ? updated(suggestion.publicationDate, value: publicationText) : nil
                    suggestion.originalPublicationDate = includeOriginalPublication ? updated(suggestion.originalPublicationDate, value: originalPublicationText) : nil
                    suggestion.editionDescription = includeEdition ? updated(suggestion.editionDescription, value: editionText) : nil
                    suggestion.volumeDescription = includeVolume ? updated(suggestion.volumeDescription, value: volumeText) : nil
                    suggestion.languageCodes = includeLanguages ? updated(suggestion.languageCodes, value: list(from: languagesText)) : nil
                    suggestion.originalLanguageCode = includeOriginalLanguage ? updated(suggestion.originalLanguageCode, value: originalLanguageText) : nil
                    suggestion.pageCount = includePages ? Int(pagesText).flatMap { updated(suggestion.pageCount, value: $0) } : nil
                    suggestion.paginationStatus = includePagination ? paginationStatus(from: paginationText).flatMap { updated(suggestion.paginationStatus, value: $0) } : nil
                    suggestion.physicalAttributes = includePhysicalAttributes ? updated(suggestion.physicalAttributes, value: physicalAttributes(from: physicalAttributesText)) : nil
                    suggestion.descriptiveNotes = includeNotes ? updated(suggestion.descriptiveNotes, value: notesText) : nil
                    let acceptedSuggestion = suggestion
                    isApplying = true
                    Task {
                        if await onApply(acceptedSuggestion) {
                            dismiss()
                        } else {
                            isApplying = false
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(isApplying)
            }
            .buttonStyle(.glass)
        }
        .padding(24)
        .frame(width: 760, height: 720)
    }

    @ViewBuilder
    private func suggestionRow<Value: Equatable & Sendable>(_ label: LocalizedStringKey, enabled: Binding<Bool>, value: Binding<String>, suggestion: SuggestedValue<Value>?) -> some View {
        if let suggestion {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Toggle(label, isOn: enabled)
                        .toggleStyle(.checkbox)
                        .frame(width: 180, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(text: value) {
                            Text(label)
                        }
                            .labelsHidden()
                            .disabled(!enabled.wrappedValue)
                        confidenceLine(for: suggestion)
                    }
                }
                .padding(.vertical, 11)
                Divider()
            }
        }
    }

    private func updated<Value: Equatable & Sendable>(_ original: SuggestedValue<Value>?, value: Value) -> SuggestedValue<Value>? {
        guard let original else { return nil }
        var result = original
        result.value = value
        return result
    }

    private func confidenceLine<Value: Equatable & Sendable>(
        for suggestion: SuggestedValue<Value>,
        includeEvidence: Bool = true
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: confidenceSymbol(for: suggestion.confidence))
            Text(confidenceLabel(for: suggestion.confidence))
            if includeEvidence {
                Text("·")
                Text(suggestion.evidence)
                    .lineLimit(2)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func confidenceSymbol(for confidence: SuggestionConfidence) -> String {
        switch confidence {
        case .high: "checkmark.circle"
        case .medium: "circle.lefthalf.filled"
        case .low: "questionmark.circle"
        }
    }

    private func confidenceLabel(for confidence: SuggestionConfidence) -> String {
        switch confidence {
        case .high: L10n.text("High confidence")
        case .medium: L10n.text("Medium confidence")
        case .low: L10n.text("Low confidence")
        }
    }

    private func list(from value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func contributorText(for contributors: [BibliographicContributor]) -> String {
        contributors.map { contributor in
            let roles = contributor.roles.map(\.label).joined(separator: ", ")
            return roles.isEmpty ? contributor.name : "\(contributor.name) | \(roles)"
        }.joined(separator: "; ")
    }

    private func contributors(from value: String) -> [BibliographicContributor] {
        value.split(separator: ";").compactMap { entry in
            let parts = entry.split(separator: "|", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let name = parts.first, !name.isEmpty else { return nil }
            let roles = parts.count > 1
                ? parts[1].split(separator: ",").compactMap { contributorRole(from: String($0)) }
                : []
            return BibliographicContributor(name: name, roles: roles)
        }
    }

    private func contributorRole(from value: String) -> ContributorRole? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ContributorRole(rawValue: normalized)
            ?? ContributorRole.allCases.first { $0.label.localizedCaseInsensitiveCompare(normalized) == .orderedSame }
    }

    private func paginationStatus(from value: String) -> PaginationStatus? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return PaginationStatus(rawValue: normalized)
            ?? PaginationStatus.allCases.first { $0.label.localizedCaseInsensitiveCompare(normalized) == .orderedSame }
    }

    private func physicalAttributes(from value: String) -> [PhysicalAttribute] {
        value.split(separator: ",").compactMap { component in
            let normalized = component.trimmingCharacters(in: .whitespacesAndNewlines)
            return PhysicalAttribute(rawValue: normalized)
                ?? PhysicalAttribute.allCases.first { $0.label.localizedCaseInsensitiveCompare(normalized) == .orderedSame }
        }
    }

    private var availableFields: [SuggestionField] {
        SuggestionField.allCases.filter { field in
            switch field {
            case .title: suggestion.title == nil
            case .subtitle: suggestion.subtitle == nil
            case .authors: suggestion.authors == nil
            case .translators: suggestion.translators == nil
            case .contributors: suggestion.contributors == nil
            case .publisher: suggestion.publisher == nil
            case .collection: suggestion.collectionName == nil
            case .collectionNumber: suggestion.collectionNumber == nil
            case .publicationPlace: suggestion.publicationPlace == nil
            case .publication: suggestion.publicationDate == nil
            case .originalPublication: suggestion.originalPublicationDate == nil
            case .edition: suggestion.editionDescription == nil
            case .volume: suggestion.volumeDescription == nil
            case .languages: suggestion.languageCodes == nil
            case .originalLanguage: suggestion.originalLanguageCode == nil
            case .pages: suggestion.pageCount == nil
            case .pagination: suggestion.paginationStatus == nil
            case .physicalAttributes: suggestion.physicalAttributes == nil
            case .description: suggestion.descriptiveNotes == nil
            }
        }
    }

    private func add(_ field: SuggestionField) {
        switch field {
        case .title:
            suggestion.title = manuallyAdded("")
            includeTitle = true
        case .subtitle:
            suggestion.subtitle = manuallyAdded("")
            includeSubtitle = true
        case .authors:
            suggestion.authors = manuallyAdded([])
            includeAuthors = true
        case .translators:
            suggestion.translators = manuallyAdded([])
            includeTranslators = true
        case .contributors:
            suggestion.contributors = manuallyAdded([])
            includeContributors = true
        case .publisher:
            suggestion.publisher = manuallyAdded("")
            includePublisher = true
        case .collection:
            suggestion.collectionName = manuallyAdded("")
            includeCollection = true
        case .collectionNumber:
            suggestion.collectionNumber = manuallyAdded("")
            includeCollectionNumber = true
        case .publicationPlace:
            suggestion.publicationPlace = manuallyAdded("")
            includePublicationPlace = true
        case .publication:
            suggestion.publicationDate = manuallyAdded("")
            includePublication = true
        case .originalPublication:
            suggestion.originalPublicationDate = manuallyAdded("")
            includeOriginalPublication = true
        case .edition:
            suggestion.editionDescription = manuallyAdded("")
            includeEdition = true
        case .volume:
            suggestion.volumeDescription = manuallyAdded("")
            includeVolume = true
        case .languages:
            suggestion.languageCodes = manuallyAdded([])
            includeLanguages = true
        case .originalLanguage:
            suggestion.originalLanguageCode = manuallyAdded("")
            includeOriginalLanguage = true
        case .pages:
            suggestion.pageCount = manuallyAdded(0)
            pagesText = ""
            includePages = true
        case .pagination:
            suggestion.paginationStatus = manuallyAdded(.nonPaginated)
            paginationText = PaginationStatus.nonPaginated.label
            includePagination = true
        case .physicalAttributes:
            suggestion.physicalAttributes = manuallyAdded([])
            includePhysicalAttributes = true
        case .description:
            suggestion.descriptiveNotes = manuallyAdded("")
            includeNotes = true
        }
    }

    private func manuallyAdded<Value: Equatable & Sendable>(_ value: Value) -> SuggestedValue<Value> {
        SuggestedValue(value: value, confidence: .low, evidence: L10n.text("Added manually"))
    }
}

private enum SuggestionField: String, CaseIterable, Identifiable {
    case title
    case subtitle
    case authors
    case translators
    case contributors
    case publisher
    case collection
    case collectionNumber
    case publicationPlace
    case publication
    case originalPublication
    case edition
    case volume
    case languages
    case originalLanguage
    case pages
    case pagination
    case physicalAttributes
    case description

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .title: "Book Title"
        case .subtitle: "Subtitle"
        case .authors: "Authors"
        case .translators: "Translators"
        case .contributors: "Contributors"
        case .publisher: "Publisher"
        case .collection: "Collection"
        case .collectionNumber: "Collection Number"
        case .publicationPlace: "Publication Place"
        case .publication: "Published"
        case .originalPublication: "Originally Published"
        case .edition: "Edition"
        case .volume: "Volume or Part"
        case .languages: "Languages"
        case .originalLanguage: "Original Language"
        case .pages: "Pages"
        case .pagination: "Pagination"
        case .physicalAttributes: "Physical Attributes"
        case .description: "Description"
        }
    }

    var systemImage: String {
        switch self {
        case .title, .subtitle: "textformat"
        case .authors, .translators, .contributors: "person"
        case .publisher, .collection, .collectionNumber: "books.vertical"
        case .publicationPlace: "mappin"
        case .publication, .originalPublication: "calendar"
        case .edition, .volume: "book.closed"
        case .languages, .originalLanguage: "character.bubble"
        case .pages, .pagination: "doc"
        case .physicalAttributes: "checklist"
        case .description: "text.alignleft"
        }
    }
}
