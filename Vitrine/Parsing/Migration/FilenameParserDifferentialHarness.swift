import Foundation

enum FilenameSuggestionField: String, CaseIterable, Sendable {
    case title
    case subtitle
    case authors
    case translators
    case contributors
    case publisher
    case collectionName
    case collectionNumber
    case publicationPlace
    case publicationDate
    case originalPublicationDate
    case editionDescription
    case volumeDescription
    case languageCodes
    case originalLanguageCode
    case pageCount
    case paginationStatus
    case physicalAttributes
    case descriptiveNotes
}

struct ParserFieldSnapshot: Equatable, Sendable {
    let value: String?
    let confidence: SuggestionConfidence?
    let evidence: String?
    let sourceSpan: Range<Int>?
}

struct ParserFieldComparison: Equatable, Sendable {
    let field: FilenameSuggestionField
    let legacy: ParserFieldSnapshot
    let v2: ParserFieldSnapshot

    var valueChanged: Bool { legacy.value != v2.value }
    var confidenceChanged: Bool { legacy.confidence != v2.confidence }
    var evidenceChanged: Bool { legacy.evidence != v2.evidence }
    var sourceSpanChanged: Bool { legacy.sourceSpan != v2.sourceSpan }
}

struct ParserDifferentialReport: Sendable {
    let sourceTitle: String
    let comparisons: [ParserFieldComparison]
    let unresolvedSegments: [UnresolvedSegment]

    var valueDifferences: [ParserFieldComparison] {
        comparisons.filter(\.valueChanged)
    }
}

struct FilenameParserDifferentialHarness: Sendable {
    let configuration: ParsingConfiguration

    init(configuration: ParsingConfiguration = .bundled) {
        self.configuration = configuration
    }

    func compare(_ sourceTitle: String) -> ParserDifferentialReport {
        let legacy = LegacyFilenameMetadataParser().suggestions(from: sourceTitle)
        let parsed = CitationMetadataParser(configuration: configuration).parse(sourceTitle)
        let v2 = parsed.suggestion
        return ParserDifferentialReport(
            sourceTitle: sourceTitle,
            comparisons: FilenameSuggestionField.allCases.map {
                ParserFieldComparison(
                    field: $0,
                    legacy: snapshot(field: $0, suggestion: legacy),
                    v2: snapshot(field: $0, suggestion: v2)
                )
            },
            unresolvedSegments: parsed.draft.unresolvedSegments
        )
    }

    private func snapshot(
        field: FilenameSuggestionField,
        suggestion: FilenameMetadataSuggestion
    ) -> ParserFieldSnapshot {
        switch field {
        case .title: snapshot(suggestion.title) { $0 }
        case .subtitle: snapshot(suggestion.subtitle) { $0 }
        case .authors: snapshot(suggestion.authors) { $0.joined(separator: " | ") }
        case .translators: snapshot(suggestion.translators) { $0.joined(separator: " | ") }
        case .contributors: snapshot(suggestion.contributors) {
            $0.map { contributor in
                "\(contributor.name)[\(contributor.roles.map(\.rawValue).joined(separator: ","))]"
            }.joined(separator: " | ")
        }
        case .publisher: snapshot(suggestion.publisher) { $0 }
        case .collectionName: snapshot(suggestion.collectionName) { $0 }
        case .collectionNumber: snapshot(suggestion.collectionNumber) { $0 }
        case .publicationPlace: snapshot(suggestion.publicationPlace) { $0 }
        case .publicationDate: snapshot(suggestion.publicationDate) { $0 }
        case .originalPublicationDate: snapshot(suggestion.originalPublicationDate) { $0 }
        case .editionDescription: snapshot(suggestion.editionDescription) { $0 }
        case .volumeDescription: snapshot(suggestion.volumeDescription) { $0 }
        case .languageCodes: snapshot(suggestion.languageCodes) { $0.joined(separator: " | ") }
        case .originalLanguageCode: snapshot(suggestion.originalLanguageCode) { $0 }
        case .pageCount: snapshot(suggestion.pageCount) { String($0) }
        case .paginationStatus: snapshot(suggestion.paginationStatus) { $0.rawValue }
        case .physicalAttributes: snapshot(suggestion.physicalAttributes) {
            $0.map(\.rawValue).joined(separator: " | ")
        }
        case .descriptiveNotes: snapshot(suggestion.descriptiveNotes) { $0 }
        }
    }

    private func snapshot<Value: Equatable & Sendable>(
        _ value: SuggestedValue<Value>?,
        render: (Value) -> String
    ) -> ParserFieldSnapshot {
        ParserFieldSnapshot(
            value: value.map { render($0.value) },
            confidence: value?.confidence,
            evidence: value?.evidence,
            sourceSpan: value?.sourceSpan
        )
    }
}
