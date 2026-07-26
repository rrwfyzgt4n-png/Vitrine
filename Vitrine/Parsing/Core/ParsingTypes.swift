import Foundation

struct SourceOffsetMap: Sendable, Equatable {
    private let characterRanges: [Range<Int>]
    let originalCharacterCount: Int

    init(characterRanges: [Range<Int>], originalCharacterCount: Int) {
        self.characterRanges = characterRanges
        self.originalCharacterCount = originalCharacterCount
    }

    func originalRange(for correctedRange: Range<Int>) -> Range<Int>? {
        guard !correctedRange.isEmpty,
              correctedRange.lowerBound >= 0,
              correctedRange.upperBound <= characterRanges.count else { return nil }
        let ranges = characterRanges[correctedRange].filter { !$0.isEmpty }
        guard let lower = ranges.map(\.lowerBound).min(),
              let upper = ranges.map(\.upperBound).max() else { return nil }
        return lower..<upper
    }
}

struct AppliedCorrection: Sendable, Equatable {
    let ruleID: String
    let correctedRange: Range<Int>
    let originalSourceRange: Range<Int>?
}

struct ParsingSource: Sendable, Equatable {
    let original: String
    let corrected: String
    let sourceMap: SourceOffsetMap
    let appliedCorrections: [AppliedCorrection]

    func originalRange(for correctedRange: Range<Int>) -> Range<Int>? {
        sourceMap.originalRange(for: correctedRange)
    }

    func originalText(in range: Range<Int>) -> String {
        let characters = Array(original)
        guard range.lowerBound >= 0, range.upperBound <= characters.count else { return "" }
        return String(characters[range])
    }
}

struct ParsingEvidence: Equatable, Sendable {
    let ruleIDs: [String]
    let originalSourceSpans: [Range<Int>]
    let appliedCorrectionIDs: [String]
    let explanationKey: String

    var coveringSourceSpan: Range<Int>? {
        guard let lower = originalSourceSpans.map(\.lowerBound).min(),
              let upper = originalSourceSpans.map(\.upperBound).max() else { return nil }
        return lower..<upper
    }
}

struct FieldCandidate<Value: Equatable & Sendable>: Equatable, Sendable {
    let value: Value
    let confidence: FieldConfidence
    let evidence: ParsingEvidence
}

enum InversionKind: String, Sendable, Codable {
    case mechanical
    case heuristic
    case none
}

struct ParsedTitleCandidate: Sendable, Equatable {
    let displayForm: String
    let sourceFilingForm: String
    let inversionKind: InversionKind
    let evidence: ParsingEvidence
}

struct UnresolvedSegment: Sendable, Equatable {
    let text: String
    let originalSourceSpan: Range<Int>
    let attemptedRuleIDs: [String]
}

struct ParseDraft: Sendable {
    var title: ParsedTitleCandidate?
    var subtitle: FieldCandidate<String>?
    var authors: FieldCandidate<[String]>?
    var translators: FieldCandidate<[String]>?
    var contributors: FieldCandidate<[BibliographicContributor]>?
    var publisher: FieldCandidate<String>?
    var collectionName: FieldCandidate<String>?
    var collectionNumber: FieldCandidate<String>?
    var publicationPlace: FieldCandidate<String>?
    var publicationDate: FieldCandidate<String>?
    var originalPublicationDate: FieldCandidate<String>?
    var editionDescription: FieldCandidate<String>?
    var volumeDescription: FieldCandidate<String>?
    var languageCodes: FieldCandidate<[String]>?
    var originalLanguageCode: FieldCandidate<String>?
    var pageCount: FieldCandidate<Int>?
    var paginationStatus: FieldCandidate<PaginationStatus>?
    var physicalAttributes: FieldCandidate<[PhysicalAttribute]>?
    var descriptiveNotes: FieldCandidate<String>?
    var unresolvedSegments: [UnresolvedSegment] = []
}

struct CitationParseResult: Sendable {
    let source: ParsingSource
    let draft: ParseDraft
    let suggestion: FilenameMetadataSuggestion
}

struct ParsedSegment: Sendable, Equatable {
    let text: String
    let correctedRange: Range<Int>
    let originalRange: Range<Int>
}

extension String {
    func characterOffsetRange(for range: Range<String.Index>) -> Range<Int> {
        distance(from: startIndex, to: range.lowerBound)..<distance(from: startIndex, to: range.upperBound)
    }

    func rangeForCharacterOffsets(_ range: Range<Int>) -> Range<String.Index> {
        index(startIndex, offsetBy: range.lowerBound)..<index(startIndex, offsetBy: range.upperBound)
    }
}
