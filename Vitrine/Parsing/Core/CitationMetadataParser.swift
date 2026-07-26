import Foundation

struct CitationMetadataParser: Sendable {
    let configuration: ParsingConfiguration

    init(configuration: ParsingConfiguration = .bundled) {
        self.configuration = configuration
    }

    func parse(_ sourceTitle: String) -> CitationParseResult {
        let source = CorrectionEngine(rules: configuration.corrections).correct(sourceTitle)
        let segments = TopLevelSegmenter().segments(in: source)
        let tail = TailParser(configuration: configuration).parse(source)
        var classified = SegmentClassifier(configuration: configuration).classify(
            source: source,
            segments: segments,
            tail: tail
        )
        let title = TitleInversionResolver(configuration: configuration).resolve(
            text: classified.titleText,
            correctedRange: classified.titleRange,
            source: source
        )
        classified.draft.title = title.title
        classified.draft.subtitle = title.subtitle
        let suggestion = FilenameSuggestionBuilder().build(from: classified.draft, source: source)
        return CitationParseResult(source: source, draft: classified.draft, suggestion: suggestion)
    }
}

struct FilenameSuggestionBuilder: Sendable {
    func build(from draft: ParseDraft, source: ParsingSource) -> FilenameMetadataSuggestion {
        FilenameMetadataSuggestion(
            title: draft.title.map {
                suggested(
                    $0.displayForm,
                    confidence: $0.inversionKind == .mechanical ? .high : .medium,
                    evidence: $0.evidence,
                    source: source
                )
            },
            subtitle: map(draft.subtitle, source: source),
            authors: map(draft.authors, source: source),
            translators: map(draft.translators, source: source),
            contributors: map(draft.contributors, source: source),
            publisher: map(draft.publisher, source: source),
            collectionName: map(draft.collectionName, source: source),
            collectionNumber: map(draft.collectionNumber, source: source),
            publicationPlace: map(draft.publicationPlace, source: source),
            publicationDate: map(draft.publicationDate, source: source),
            originalPublicationDate: map(draft.originalPublicationDate, source: source),
            editionDescription: map(draft.editionDescription, source: source),
            volumeDescription: map(draft.volumeDescription, source: source),
            languageCodes: map(draft.languageCodes, source: source),
            originalLanguageCode: map(draft.originalLanguageCode, source: source),
            pageCount: map(draft.pageCount, source: source),
            paginationStatus: map(draft.paginationStatus, source: source),
            physicalAttributes: map(draft.physicalAttributes, source: source),
            descriptiveNotes: map(draft.descriptiveNotes, source: source)
        )
    }

    private func map<Value: Equatable & Sendable>(
        _ candidate: FieldCandidate<Value>?,
        source: ParsingSource
    ) -> SuggestedValue<Value>? {
        candidate.map {
            suggested($0.value, confidence: confidence($0.confidence), evidence: $0.evidence, source: source)
        }
    }

    private func suggested<Value: Equatable & Sendable>(
        _ value: Value,
        confidence: SuggestionConfidence,
        evidence: ParsingEvidence,
        source: ParsingSource
    ) -> SuggestedValue<Value> {
        let span = evidence.coveringSourceSpan
        let text = span.map(source.originalText) ?? evidence.ruleIDs.joined(separator: ", ")
        return SuggestedValue(value: value, confidence: confidence, evidence: text, sourceSpan: span)
    }

    private func confidence(_ value: FieldConfidence) -> SuggestionConfidence {
        switch value {
        case .mechanical: .high
        case .heuristic: .medium
        case .unresolved: .low
        }
    }

}
