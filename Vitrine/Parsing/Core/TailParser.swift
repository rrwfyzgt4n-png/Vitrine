import Foundation

struct TailParseResult: Sendable {
    var publicationDate: FieldCandidate<String>?
    var originalPublicationDate: FieldCandidate<String>?
    var pageCount: FieldCandidate<Int>?
    var paginationStatus: FieldCandidate<PaginationStatus>?
    var editionDescription: FieldCandidate<String>?
    var volumeDescription: FieldCandidate<String>?
    var physicalAttributes: FieldCandidate<[PhysicalAttribute]>?
    var descriptiveNotes: FieldCandidate<String>?
    var terminalBoundary: Int?
    var consumedRanges: [Range<Int>] = []
}

struct TailParser: Sendable {
    let configuration: ParsingConfiguration

    func parse(_ source: ParsingSource) -> TailParseResult {
        var result = TailParseResult()
        let value = source.corrected

        let pageMatches = configuration.rules(category: "page-count")
            .flatMap { $0.matches(in: value) }
            .sorted { $0.correctedRange.lowerBound < $1.correctedRange.lowerBound }
        if let page = pageMatches.last,
           let raw = page.groups.first,
           let count = Int(raw) {
            result.pageCount = FieldCandidate(
                value: count,
                confidence: page.rule.confidence,
                evidence: source.evidence(
                    ruleIDs: [page.rule.id],
                    correctedRanges: [page.correctedRange],
                    explanationKey: "parser.page-count"
                )
            )
            result.consumedRanges.append(page.correctedRange)
        }

        if let pagination = configuration.rules(category: "pagination")
            .flatMap({ $0.matches(in: value) }).last {
            result.paginationStatus = FieldCandidate(
                value: .nonPaginated,
                confidence: pagination.rule.confidence,
                evidence: source.evidence(
                    ruleIDs: [pagination.rule.id],
                    correctedRanges: [pagination.correctedRange],
                    explanationKey: "parser.pagination.non-paginated"
                )
            )
            result.consumedRanges.append(pagination.correctedRange)
        }

        let terminalSingleYears = configuration.rules(category: "publication-year")
            .flatMap { $0.matches(in: value) }
            .filter { yearMatch in
                !pageMatches.contains(where: { pageMatch in
                    yearMatch.correctedRange.overlaps(pageMatch.correctedRange)
                }) &&
                    isTerminalYear(yearMatch.correctedRange, in: value, page: result.pageCount != nil)
            }

        if let paired = configuration.rules(category: "paired-years")
            .flatMap({ $0.matches(in: value) })
            .filter({ isTerminalYear($0.correctedRange, in: value, page: result.pageCount != nil) })
            .last,
           paired.groups.count == 2 {
            result.publicationDate = candidate(
                paired.groups[0],
                match: paired,
                source: source,
                key: "parser.publication-year"
            )
            result.originalPublicationDate = candidate(
                paired.groups[1],
                match: paired,
                source: source,
                key: "parser.original-publication-year"
            )
            result.terminalBoundary = paired.correctedRange.lowerBound
            result.consumedRanges.append(paired.correctedRange)
        } else if let multi = configuration.rules(category: "publication-year-range")
            .flatMap({ $0.matches(in: value) })
            .filter({ isTerminalYear($0.correctedRange, in: value, page: result.pageCount != nil) })
            .last,
                  multi.groups.count == 2 {
            result.publicationDate = candidate(
                "\(multi.groups[0])–\(multi.groups[1])",
                match: multi,
                source: source,
                key: "parser.publication-year-range"
            )
            result.terminalBoundary = multi.correctedRange.lowerBound
            result.consumedRanges.append(multi.correctedRange)
        } else if let year = terminalSingleYears.last,
                  let raw = year.groups.first {
            result.publicationDate = candidate(
                raw,
                match: year,
                source: source,
                key: "parser.publication-year"
            )
            result.terminalBoundary = year.correctedRange.lowerBound
            result.consumedRanges.append(year.correctedRange)
        }

        if result.publicationDate == nil,
           let undated = configuration.rules(category: "undated")
            .flatMap({ $0.matches(in: value) }).last {
            result.terminalBoundary = undated.correctedRange.lowerBound
            result.consumedRanges.append(undated.correctedRange)
        } else if result.terminalBoundary == nil {
            result.terminalBoundary = pageMatches.last?.correctedRange.lowerBound ??
                configuration.rules(category: "pagination").flatMap({ $0.matches(in: value) }).last?.correctedRange.lowerBound
        }

        if let edition = configuration.rules(category: "edition")
            .flatMap({ $0.matches(in: value) }).first {
            let text = edition.groups.first?.parserTrimmed ?? edition.fullText.parserTrimmed
            result.editionDescription = candidate(text, match: edition, source: source, key: "parser.edition")
            result.consumedRanges.append(edition.correctedRange)
        }
        if let volume = configuration.rules(category: "volume")
            .flatMap({ $0.matches(in: value) }).first {
            let text = volume.groups.first?.parserTrimmed ?? volume.fullText.parserTrimmed
            result.volumeDescription = candidate(text, match: volume, source: source, key: "parser.volume")
            result.consumedRanges.append(volume.correctedRange)
        }

        let attributes = physicalAttributes(in: source)
        if !attributes.values.isEmpty {
            result.physicalAttributes = FieldCandidate(
                value: attributes.values,
                confidence: .mechanical,
                evidence: source.evidence(
                    ruleIDs: attributes.ruleIDs,
                    correctedRanges: attributes.ranges,
                    explanationKey: "parser.physical-attributes"
                )
            )
            result.consumedRanges.append(contentsOf: attributes.ranges)
        }

        var notes: [(String, Range<Int>, String)] = []
        for provenance in configuration.rules(category: "provenance")
            .flatMap({ $0.matches(in: value) }) {
            notes.append((provenance.fullText.parserTrimmed, provenance.correctedRange, provenance.rule.id))
            result.consumedRanges.append(provenance.correctedRange)
        }
        if let page = pageMatches.last {
            let characters = Array(value)
            let tail = page.correctedRange.upperBound..<characters.count
            let text = String(characters[tail]).parserTrimmed
            if !text.isEmpty {
                notes.append((text, tail, "tail.residual-description.v1"))
            }
        }
        if !notes.isEmpty {
            result.descriptiveNotes = FieldCandidate(
                value: notes.map(\.0).reduce(into: [String]()) {
                    if !$0.contains($1) { $0.append($1) }
                }.joined(separator: "; "),
                confidence: .heuristic,
                evidence: source.evidence(
                    ruleIDs: notes.map(\.2),
                    correctedRanges: notes.map(\.1),
                    explanationKey: "parser.descriptive-notes"
                )
            )
        }
        return result
    }

    private func candidate(
        _ value: String,
        match: ParsingMatch,
        source: ParsingSource,
        key: String
    ) -> FieldCandidate<String> {
        FieldCandidate(
            value: value,
            confidence: match.rule.confidence,
            evidence: source.evidence(
                ruleIDs: [match.rule.id],
                correctedRanges: [match.correctedRange],
                explanationKey: key
            )
        )
    }

    private func isTerminalYear(_ range: Range<Int>, in value: String, page: Bool) -> Bool {
        let characters = Array(value)
        let suffix = String(characters[range.upperBound...])
        if page {
            return TailPatterns.pageAfterYear.firstMatch(
                in: suffix,
                range: NSRange(suffix.startIndex..., in: suffix)
            ) != nil
        }
        return suffix.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).isEmpty ||
            TailPatterns.physicalAfterYear.firstMatch(
                in: suffix,
                range: NSRange(suffix.startIndex..., in: suffix)
            ) != nil
    }

    private func physicalAttributes(
        in source: ParsingSource
    ) -> (values: [PhysicalAttribute], ranges: [Range<Int>], ruleIDs: [String]) {
        let mapping: [(String, PhysicalAttribute)] = [
            ("physical-illustrated", .illustrated),
            ("physical-maps", .maps),
            ("physical-foldout-maps", .foldoutMaps),
            ("physical-battle-plans", .battlePlans),
            ("physical-genealogical-trees", .genealogicalTrees),
            ("physical-black-white", .blackAndWhite),
            ("physical-dust-jacket", .dustJacket),
            ("physical-slipcase", .slipcase),
            ("physical-double-pages", .doublePages),
        ]
        var values: [PhysicalAttribute] = []
        var ranges: [Range<Int>] = []
        var ids: [String] = []
        for (category, attribute) in mapping {
            let matches = configuration.rules(category: category).flatMap { $0.matches(in: source.corrected) }
            guard !matches.isEmpty else { continue }
            if !values.contains(attribute) { values.append(attribute) }
            ranges.append(contentsOf: matches.map(\.correctedRange))
            ids.append(contentsOf: matches.map(\.rule.id))
        }
        return (values, ranges, ids)
    }
}

private enum TailPatterns {
    static let pageAfterYear = try! NSRegularExpression(
        pattern: #"(?i)(?:\s*[,;.]?\s*|\s*\(\d{4}\)\s*)[^,]*\d{1,4}\s*p"#
    )
    static let physicalAfterYear = try! NSRegularExpression(
        pattern: #"(?i)^\s*(?:ill\.?|cartes?|maps?|non[- ]pagin[eé]|avec\b|dans\b)"#
    )
}
