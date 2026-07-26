import Foundation

struct ClassifiedCitation: Sendable {
    var draft: ParseDraft
    var titleRange: Range<Int>
    var titleText: String
}

struct SegmentClassifier: Sendable {
    let configuration: ParsingConfiguration
    private let patterns = CitationPatterns.shared

    func classify(
        source: ParsingSource,
        segments: [ParsedSegment],
        tail: TailParseResult
    ) -> ClassifiedCitation {
        let value = source.corrected
        var draft = ParseDraft()
        draft.publicationDate = tail.publicationDate
        draft.originalPublicationDate = tail.originalPublicationDate
        draft.pageCount = tail.pageCount
        draft.paginationStatus = tail.paginationStatus
        draft.editionDescription = tail.editionDescription
        draft.volumeDescription = tail.volumeDescription
        draft.physicalAttributes = tail.physicalAttributes
        draft.descriptiveNotes = tail.descriptiveNotes

        let roleMatches = configuration.contributorMarkers
            .flatMap { rule in rule.matches(in: value) }
            .sorted(by: orderedMatches)
        let translatorMatches = roleMatches.filter {
            ["translator", "translator-notes"].contains($0.rule.category)
        }
        let contributorMatches = roleMatches.filter { $0.rule.category == "contributor" }
        let authorMatches = roleMatches.filter { $0.rule.category == "author" }

        let translators = translatorMatches.flatMap { match -> [String] in
            let raw = match.groups.last(where: { !$0.isEmpty }) ?? ""
            return splitPeople(trimResponsibilityTail(raw))
        }
        if !translators.isEmpty {
            draft.translators = listCandidate(
                unique(translators),
                matches: translatorMatches,
                source: source,
                key: "parser.translators"
            )
        }

        var contributors: [BibliographicContributor] = []
        for match in contributorMatches {
            guard let raw = match.groups.last(where: { !$0.isEmpty }) else { continue }
            let roles = (match.rule.roles ?? []).compactMap(ContributorRole.init(rawValue:))
            for name in splitPeople(trimResponsibilityTail(raw)) where !name.isEmpty {
                merge(.init(name: name, roles: roles), into: &contributors)
            }
        }
        for match in translatorMatches where match.rule.category == "translator-notes" {
            guard let raw = match.groups.last(where: { !$0.isEmpty }) else { continue }
            for name in splitPeople(trimResponsibilityTail(raw)) {
                merge(.init(name: name, roles: [.annotator]), into: &contributors)
            }
        }

        var authors: [String] = []
        let protectedRanges = translatorMatches.map(\.correctedRange) + contributorMatches.map(\.correctedRange)
        let usableAuthorMatches = authorMatches.filter { candidate in
            !protectedRanges.contains(where: {
                $0.lowerBound <= candidate.correctedRange.lowerBound &&
                    $0.upperBound >= candidate.correctedRange.upperBound
            })
        }
        if let selected = usableAuthorMatches.first,
           let raw = selected.groups.last(where: { !$0.isEmpty }) {
            authors = splitPeople(trimResponsibilityTail(raw))
        }

        let terminalBoundary = tail.terminalBoundary ?? value.count
        let characters = Array(value)
        let relevantSegments = segments.compactMap { segment -> ParsedSegment? in
            guard segment.correctedRange.lowerBound < terminalBoundary else { return nil }
            let upper = min(segment.correctedRange.upperBound, terminalBoundary)
            let range = segment.correctedRange.lowerBound..<upper
            guard !range.isEmpty, let original = source.originalRange(for: range) else { return nil }
            return ParsedSegment(
                text: String(characters[range]).trimmingCharacters(
                    in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:"))
                ),
                correctedRange: range,
                originalRange: original
            )
        }
        let languages = languages(in: source, hasTranslators: !translators.isEmpty)
        draft.languageCodes = languages.current
        draft.originalLanguageCode = languages.original

        let publisherResult = publisherAndPlace(
            source: source,
            segments: relevantSegments,
            roleMatches: roleMatches
        )
        draft.publisher = publisherResult.publisher
        draft.publicationPlace = publisherResult.place

        let collectionResult = collection(
            source: source,
            segments: relevantSegments,
            publisherBoundary: publisherResult.boundary
        )
        draft.collectionName = collectionResult.name
        draft.collectionNumber = collectionResult.number

        var titleStart = 0
        let selectedAuthorMatches = usableAuthorMatches.filter { match in
            authors.contains { match.fullText.localizedCaseInsensitiveContains($0) }
        }
        var titleBoundaryCandidates = (
            contributorMatches + translatorMatches + selectedAuthorMatches
        ).map(\.correctedRange.lowerBound)
        titleBoundaryCandidates.append(contentsOf: [
            publisherResult.boundary,
            collectionResult.boundary,
            languages.boundary,
            tail.terminalBoundary,
        ].compactMap { $0 })

        let privateOwners = configuration.rules(category: "provenance-private-owners")
            .flatMap { $0.matches(in: value) }.first
        if let privateOwners, let owners = privateOwners.groups.first?.parserTrimmed, !owners.isEmpty {
            let ownerNote = "Private collection owners: \(owners)"
            draft.descriptiveNotes = mergeNotes(
                existing: draft.descriptiveNotes,
                value: ownerNote,
                match: privateOwners,
                source: source
            )
            if let ownerRange = privateOwners.groupRanges.first ?? nil {
                titleBoundaryCandidates.append(ownerRange.lowerBound)
            }
        }

        if let selectedWorks = selectedWorksStructure(in: value, source: source) {
            authors = [selectedWorks.author]
            contributors.removeAll { SearchNormalizer.normalize($0.name) == SearchNormalizer.normalize(selectedWorks.editor) }
            merge(.init(name: selectedWorks.editor, roles: [.compiler, .editor]), into: &contributors)
            titleStart = selectedWorks.titleRange.lowerBound
            titleBoundaryCandidates.append(selectedWorks.titleRange.upperBound)
        } else if let authorFirst = authorFirstStructure(
            source: source,
            segments: relevantSegments,
            volume: tail.volumeDescription
        ) {
            authors = [authorFirst.author]
            titleStart = authorFirst.titleStart
        }

        if authors.isEmpty,
           let editor = contributors.first(where: {
               $0.roles == [.editor] ||
                   $0.roles.contains(.generalEditor) ||
                   ($0.roles.contains(.illustrator) && $0.roles.contains(.iconographer))
           }) {
            authors = [editor.name]
        }

        if authors.isEmpty,
           let publisherIndex = publisherResult.segmentIndex,
           publisherIndex > 0 {
            let candidate = relevantSegments[publisherIndex - 1]
            if looksLikeUnmarkedPerson(candidate.text),
               !candidate.text.localizedCaseInsensitiveContains("Collection") {
                authors = splitPeople(candidate.text)
                titleBoundaryCandidates.append(candidate.correctedRange.lowerBound)
            }
        }

        if !authors.isEmpty {
            let authorEvidenceMatches = usableAuthorMatches.filter { match in
                authors.contains { author in
                    match.fullText.localizedCaseInsensitiveContains(author)
                }
            }
            if !authorEvidenceMatches.isEmpty {
                draft.authors = listCandidate(
                    unique(authors),
                    matches: authorEvidenceMatches,
                    source: source,
                    key: "parser.authors"
                )
            } else {
                let range = originalCorrectedRange(for: authors[0], in: value) ?? titleStart..<min(value.count, titleStart + authors[0].count)
                draft.authors = FieldCandidate(
                    value: unique(authors),
                    confidence: .heuristic,
                    evidence: source.evidence(
                        ruleIDs: ["contributor.positional-fallback.v1"],
                        correctedRanges: [range],
                        explanationKey: "parser.authors.positional"
                    )
                )
            }
        }
        if !contributors.isEmpty {
            draft.contributors = FieldCandidate(
                value: contributors,
                confidence: .mechanical,
                evidence: source.evidence(
                    ruleIDs: unique(contributorMatches.map(\.rule.id) + translatorMatches.filter {
                        $0.rule.category == "translator-notes"
                    }.map(\.rule.id)),
                    correctedRanges: contributorMatches.map(\.correctedRange) + translatorMatches.filter {
                        $0.rule.category == "translator-notes"
                    }.map(\.correctedRange),
                    explanationKey: "parser.contributors"
                )
            )
        }

        if let volume = configuration.rules(category: "volume").flatMap({ $0.matches(in: value) }).first {
            titleBoundaryCandidates.append(volume.correctedRange.lowerBound)
        }

        let boundary = titleBoundaryCandidates
            .filter { $0 > titleStart }
            .min() ?? terminalBoundary
        let safeBoundary = max(titleStart, min(boundary, value.count))
        var titleText = String(Array(value)[titleStart..<safeBoundary])
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        if let volume = tail.volumeDescription?.value,
           let range = titleText.range(of: volume, options: [.caseInsensitive, .diacriticInsensitive]) {
            titleText.removeSubrange(range)
            titleText = titleText.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        }

        let attempted = configuration.contributorMarkers.map(\.definition.id)
        let recognizedValues = authors + translators + contributors.map(\.name) + [
            draft.publisher?.value,
            draft.publicationPlace?.value,
            draft.collectionName?.value,
            privateOwners?.groups.first,
            languages.current?.value.joined(separator: " "),
        ].compactMap { $0 }
        for segment in relevantSegments where
            segment.correctedRange.lowerBound >= safeBoundary &&
            !isConsumed(
                segment,
                roleMatches: roleMatches,
                publisher: publisherResult.consumedRanges,
                collection: collectionResult.consumedRanges,
                tail: tail.consumedRanges
            ) &&
            !recognizedValues.contains(where: {
                SearchNormalizer.normalize(segment.text).contains(SearchNormalizer.normalize($0)) ||
                    SearchNormalizer.normalize($0).contains(SearchNormalizer.normalize(segment.text))
            }) &&
            !SearchNormalizer.normalize(segment.text).hasPrefix("en francais") {
            draft.unresolvedSegments.append(UnresolvedSegment(
                text: segment.text,
                originalSourceSpan: segment.originalRange,
                attemptedRuleIDs: attempted
            ))
        }

        return ClassifiedCitation(
            draft: draft,
            titleRange: titleStart..<safeBoundary,
            titleText: titleText
        )
    }

    private func orderedMatches(_ lhs: ParsingMatch, _ rhs: ParsingMatch) -> Bool {
        if lhs.rule.precedence != rhs.rule.precedence { return lhs.rule.precedence > rhs.rule.precedence }
        if lhs.rule.specificity != rhs.rule.specificity { return lhs.rule.specificity > rhs.rule.specificity }
        return lhs.correctedRange.lowerBound < rhs.correctedRange.lowerBound
    }

    private func listCandidate(
        _ values: [String],
        matches: [ParsingMatch],
        source: ParsingSource,
        key: String
    ) -> FieldCandidate<[String]> {
        FieldCandidate(
            value: values,
            confidence: matches.allSatisfy { $0.rule.confidence == .mechanical } ? .mechanical : .heuristic,
            evidence: source.evidence(
                ruleIDs: unique(matches.map(\.rule.id)),
                correctedRanges: matches.map(\.correctedRange),
                explanationKey: key
            )
        )
    }

    private func publisherAndPlace(
        source: ParsingSource,
        segments: [ParsedSegment],
        roleMatches: [ParsingMatch]
    ) -> (
        publisher: FieldCandidate<String>?,
        place: FieldCandidate<String>?,
        boundary: Int?,
        segmentIndex: Int?,
        consumedRanges: [Range<Int>]
    ) {
        let publisherRules = configuration.rules(category: "publisher")
        var publisherIndex: Int?
        var markerMatch: ParsingMatch?
        for (index, segment) in segments.enumerated() {
            if !configuration.rules(category: "edition")
                .flatMap({ $0.matches(in: segment.text) }).isEmpty {
                continue
            }
            if let found = publisherRules.flatMap({ $0.matches(in: segment.text) }).first {
                publisherIndex = index
                markerMatch = ParsingMatch(
                    rule: found.rule,
                    fullText: found.fullText,
                    correctedRange: (segment.correctedRange.lowerBound + found.correctedRange.lowerBound)..<(segment.correctedRange.lowerBound + found.correctedRange.upperBound),
                    groups: found.groups,
                    groupRanges: found.groupRanges
                )
                break
            }
        }

        if publisherIndex == nil, !segments.isEmpty {
            var candidateIndex = segments.count - 1
            while candidateIndex >= 0, isPlaceValue(segments[candidateIndex].text) {
                candidateIndex -= 1
            }
            if candidateIndex >= 0,
               !looksLikeTitleContinuation(segments[candidateIndex].text) {
                publisherIndex = candidateIndex
            }
        }
        guard let index = publisherIndex else { return (nil, nil, nil, nil, []) }
        let fallbackSegment = segments[index]
        if markerMatch == nil,
           roleMatches.contains(where: { $0.correctedRange.overlaps(fallbackSegment.correctedRange) }) ||
            !configuration.rules(category: "volume").flatMap({ $0.matches(in: fallbackSegment.text) }).isEmpty ||
            !configuration.rules(category: "edition").flatMap({ $0.matches(in: fallbackSegment.text) }).isEmpty ||
            SearchNormalizer.normalize(fallbackSegment.text).hasPrefix("gracieusete de") {
            let trailingPlaces = Array(segments[(index + 1)...]).filter { isPlaceValue($0.text) }
            return (
                nil,
                placeCandidate(from: trailingPlaces, source: source),
                nil,
                nil,
                trailingPlaces.map(\.correctedRange)
            )
        }

        var publisherText = segments[index].text.parserTrimmed
        var publisherRanges = [segments[index].correctedRange]
        let strongPrefixes = ["edition", "editions", "ed.", "librairie", "presses", "imprimerie", "typ."]
        if let markerMatch,
           strongPrefixes.contains(SearchNormalizer.normalize(markerMatch.fullText)),
           markerMatch.correctedRange.lowerBound > segments[index].correctedRange.lowerBound {
            let start = markerMatch.correctedRange.lowerBound
            publisherText = String(Array(source.corrected)[start..<segments[index].correctedRange.upperBound]).parserTrimmed
            publisherRanges = [start..<segments[index].correctedRange.upperBound]
        }
        var placeSegments: [ParsedSegment] = []
        var cursor = index + 1
        if cursor < segments.count,
           SearchNormalizer.normalize(segments[cursor].text).hasPrefix("inc") {
            publisherText += ", \(segments[cursor].text.parserTrimmed)"
            publisherRanges.append(segments[cursor].correctedRange)
            cursor += 1
        }
        while cursor < segments.count {
            let segment = segments[cursor]
            guard isPlaceValue(segment.text) else { break }
            placeSegments.append(segment)
            cursor += 1
        }

        if placeSegments.isEmpty {
            let places = configuration.aliases.filter { $0.category == "place" }
                .sorted { $0.match.count > $1.match.count }
            for place in places {
                if let range = publisherText.range(
                    of: place.match,
                    options: [.caseInsensitive, .diacriticInsensitive, .backwards]
                ), String(publisherText[range.upperBound...]).parserTrimmed.isEmpty {
                    let placeText = String(publisherText[range]).parserTrimmed
                    publisherText = String(publisherText[..<range.lowerBound]).parserTrimmed
                    if !publisherText.isEmpty,
                       let correctedPlace = originalCorrectedRange(for: placeText, in: source.corrected) {
                        let evidence = source.evidence(
                            ruleIDs: ["publication-place.trailing-position.v1"],
                            correctedRanges: [correctedPlace],
                            explanationKey: "parser.publication-place"
                        )
                        let publisherEvidence = source.evidence(
                            ruleIDs: [markerMatch?.rule.id ?? "publisher.trailing-segment.v1"],
                            correctedRanges: publisherRanges,
                            explanationKey: "parser.publisher"
                        )
                        return (
                            FieldCandidate(value: publisherText, confidence: .heuristic, evidence: publisherEvidence),
                            FieldCandidate(value: place.canonicalValue, confidence: .heuristic, evidence: evidence),
                            segments[index].correctedRange.lowerBound,
                            index,
                            publisherRanges + [correctedPlace]
                        )
                    }
                }
            }
        }

        guard !publisherText.isEmpty else { return (nil, nil, nil, nil, []) }
        let publisher = FieldCandidate(
            value: publisherText,
            confidence: markerMatch == nil ? .heuristic : markerMatch!.rule.confidence,
            evidence: source.evidence(
                ruleIDs: [markerMatch?.rule.id ?? "publisher.trailing-segment.v1"],
                correctedRanges: publisherRanges,
                explanationKey: "parser.publisher"
            )
        )
        let place: FieldCandidate<String>? = placeSegments.isEmpty ? nil : FieldCandidate(
            value: placeSegments.map { configuration.alias(category: "place", value: $0.text.parserTrimmed) }
                .joined(separator: ", "),
            confidence: .heuristic,
            evidence: source.evidence(
                ruleIDs: ["publication-place.trailing-position.v1"],
                correctedRanges: placeSegments.map(\.correctedRange),
                explanationKey: "parser.publication-place"
            )
        )
        return (
            publisher,
            place,
            segments[index].correctedRange.lowerBound,
            index,
            publisherRanges + placeSegments.map(\.correctedRange)
        )
    }

    private func collection(
        source: ParsingSource,
        segments: [ParsedSegment],
        publisherBoundary: Int?
    ) -> (
        name: FieldCandidate<String>?,
        number: FieldCandidate<String>?,
        boundary: Int?,
        consumedRanges: [Range<Int>]
    ) {
        for (index, segment) in segments.enumerated() {
            if let publisherBoundary, segment.correctedRange.lowerBound > publisherBoundary {
                break
            }
            let normalized = SearchNormalizer.normalize(segment.text)
            let isPublisherImprint = segment.correctedRange.lowerBound == publisherBoundary &&
                normalized.hasPrefix("collection ") &&
                !segment.text.contains(":")
            for rule in configuration.collectionMarkers.sorted(by: {
                $0.definition.precedence > $1.definition.precedence
            }) {
                if isPublisherImprint, rule.definition.id == "collection.explicit-marker.v1" {
                    continue
                }
                if rule.definition.id == "collection.quoted.v1" {
                    guard index + 1 < segments.count,
                          configuration.rules(category: "publisher").contains(where: {
                              !$0.matches(in: segments[index + 1].text).isEmpty
                          }) else {
                        continue
                    }
                }
                let searchValue = segment.text
                let matches = rule.matches(in: searchValue)
                if let match = matches.first,
                   let rawName = match.groups.first,
                   !rawName.isEmpty {
                    let name = configuration.alias(category: "collection", value: rawName.parserTrimmed)
                    let evidence = source.evidence(
                        ruleIDs: [match.rule.id],
                        correctedRanges: [segment.correctedRange],
                        explanationKey: "parser.collection"
                    )
                    let number = match.groups.count > 1 ? match.groups[1].parserTrimmed : ""
                    return (
                        FieldCandidate(value: name, confidence: match.rule.confidence, evidence: evidence),
                        number.isEmpty ? nil : FieldCandidate(value: number, confidence: match.rule.confidence, evidence: evidence),
                        segment.correctedRange.lowerBound,
                        [segment.correctedRange]
                    )
                }
            }
            if index + 1 < segments.count,
               configuration.rules(category: "publisher").contains(where: {
                   !$0.matches(in: segments[index + 1].text).isEmpty
               }),
               let quoted = patterns.leadingQuoted.firstMatch(
                in: segment.text,
                range: NSRange(segment.text.startIndex..., in: segment.text)
            ), quoted.numberOfRanges > 1,
               let range = Range(quoted.range(at: 1), in: segment.text) {
                let raw = String(segment.text[range])
                return (
                    FieldCandidate(
                        value: configuration.alias(category: "collection", value: raw),
                        confidence: .heuristic,
                        evidence: source.evidence(
                            ruleIDs: ["collection.quoted-prefix.v1"],
                            correctedRanges: [segment.correctedRange],
                            explanationKey: "parser.collection"
                        )
                    ),
                    nil,
                    segment.correctedRange.lowerBound,
                    [segment.correctedRange]
                )
            }
        }
        return (nil, nil, nil, [])
    }

    private func languages(
        in source: ParsingSource,
        hasTranslators: Bool
    ) -> (
        current: FieldCandidate<[String]>?,
        original: FieldCandidate<String>?,
        boundary: Int?
    ) {
        let value = source.corrected
        if let match = patterns.frenchItalian.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let range = Range(match.range, in: value) {
            let corrected = value.characterOffsetRange(for: range)
            let evidence = source.evidence(
                ruleIDs: ["language.explicit.multiple.v1"],
                correctedRanges: [corrected],
                explanationKey: "parser.languages"
            )
            return (FieldCandidate(value: ["fr", "it"], confidence: .mechanical, evidence: evidence), nil, corrected.lowerBound)
        }
        for alias in configuration.languageSourcePatterns {
            guard let match = alias.regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
                  let range = Range(match.range, in: value) else { continue }
            let corrected = value.characterOffsetRange(for: range)
            let evidence = source.evidence(
                ruleIDs: ["language.translation-source.v1", alias.definition.id],
                correctedRanges: [corrected],
                explanationKey: "parser.translation-language"
            )
            return (
                FieldCandidate(value: ["fr"], confidence: .mechanical, evidence: evidence),
                FieldCandidate(value: alias.definition.canonicalValue, confidence: .mechanical, evidence: evidence),
                corrected.lowerBound
            )
        }
        if hasTranslators,
           let match = patterns.englishTranslation.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let range = Range(match.range, in: value) {
            let corrected = value.characterOffsetRange(for: range)
            return (
                FieldCandidate(
                    value: ["en"],
                    confidence: .heuristic,
                    evidence: source.evidence(
                        ruleIDs: ["language.english-translation.v1"],
                        correctedRanges: [corrected],
                        explanationKey: "parser.languages"
                    )
                ),
                nil,
                corrected.lowerBound
            )
        }
        if let match = patterns.explicitFrench.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
           let range = Range(match.range, in: value) {
            let corrected = value.characterOffsetRange(for: range)
            return (
                FieldCandidate(
                    value: ["fr"],
                    confidence: .mechanical,
                    evidence: source.evidence(
                        ruleIDs: ["language.explicit.french.v1"],
                        correctedRanges: [corrected],
                        explanationKey: "parser.languages"
                    )
                ),
                nil,
                corrected.lowerBound
            )
        }
        return (nil, nil, nil)
    }

    private func selectedWorksStructure(
        in value: String,
        source: ParsingSource
    ) -> (author: String, editor: String, titleRange: Range<Int>)? {
        guard let match = patterns.selectedWorks.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              match.numberOfRanges == 4,
              let authorRange = Range(match.range(at: 1), in: value),
              let titleRange = Range(match.range(at: 2), in: value),
              let editorRange = Range(match.range(at: 3), in: value) else { return nil }
        return (
            String(value[authorRange]).parserTrimmed,
            String(value[editorRange]).parserTrimmed,
            value.characterOffsetRange(for: titleRange)
        )
    }

    private func authorFirstStructure(
        source: ParsingSource,
        segments: [ParsedSegment],
        volume: FieldCandidate<String>?
    ) -> (author: String, titleStart: Int)? {
        guard segments.count > 1, volume != nil else { return nil }
        let first = segments[0].text
        guard let match = patterns.authorCredential.firstMatch(in: first, range: NSRange(first.startIndex..., in: first)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: first) else { return nil }
        let author = String(first[range]).parserTrimmed
        guard !author.isEmpty else { return nil }
        return (author, segments[1].correctedRange.lowerBound)
    }

    private func mergeNotes(
        existing: FieldCandidate<String>?,
        value: String,
        match: ParsingMatch,
        source: ParsingSource
    ) -> FieldCandidate<String> {
        let merged = [value, existing?.value].compactMap { $0 }.joined(separator: "; ")
        return FieldCandidate(
            value: merged,
            confidence: .heuristic,
            evidence: ParsingEvidence(
                ruleIDs: unique((existing?.evidence.ruleIDs ?? []) + [match.rule.id]),
                originalSourceSpans: (existing?.evidence.originalSourceSpans ?? []) +
                    source.evidence(
                        ruleIDs: [match.rule.id],
                        correctedRanges: [match.correctedRange],
                        explanationKey: "parser.provenance"
                    ).originalSourceSpans,
                appliedCorrectionIDs: unique(existing?.evidence.appliedCorrectionIDs ?? []),
                explanationKey: "parser.descriptive-notes"
            )
        )
    }

    private func trimResponsibilityTail(_ value: String) -> String {
        let range = patterns.responsibilityBoundary.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ).flatMap { Range($0.range, in: value) }
        return String(value[..<(range?.lowerBound ?? value.endIndex)]).parserTrimmed
    }

    private func splitPeople(_ value: String) -> [String] {
        let range = NSRange(value.startIndex..., in: value)
        var result: [String] = []
        var cursor = value.startIndex
        for match in patterns.personSeparator.matches(in: value, range: range) {
            guard let matchRange = Range(match.range, in: value) else { continue }
            result.append(String(value[cursor..<matchRange.lowerBound]).parserTrimmed)
            cursor = matchRange.upperBound
        }
        result.append(String(value[cursor...]).parserTrimmed)
        return result.filter { !$0.isEmpty }
    }

    private func merge(_ value: BibliographicContributor, into result: inout [BibliographicContributor]) {
        if let index = result.firstIndex(where: {
            SearchNormalizer.normalize($0.name) == SearchNormalizer.normalize(value.name)
        }) {
            for role in value.roles where !result[index].roles.contains(role) {
                result[index].roles.append(role)
            }
        } else {
            result.append(value)
        }
    }

    private func looksLikeUnmarkedPerson(_ value: String) -> Bool {
        let clean = value.parserTrimmed
        guard clean.count >= 3,
              patterns.fourDigitYear.firstMatch(
                  in: clean,
                  range: NSRange(clean.startIndex..., in: clean)
              ) == nil,
              patterns.personStopWord.firstMatch(
                  in: clean,
                  range: NSRange(clean.startIndex..., in: clean)
              ) == nil else {
            return false
        }
        return patterns.personShape.firstMatch(
            in: clean,
            range: NSRange(clean.startIndex..., in: clean)
        ) != nil
    }

    private func isPlaceValue(_ value: String) -> Bool {
        configuration.aliases.contains {
            $0.category == "place" &&
                SearchNormalizer.normalize($0.match) == SearchNormalizer.normalize(value.parserTrimmed)
        }
    }

    private func placeCandidate(
        from segments: [ParsedSegment],
        source: ParsingSource
    ) -> FieldCandidate<String>? {
        guard !segments.isEmpty else { return nil }
        return FieldCandidate(
            value: segments.map {
                configuration.alias(category: "place", value: $0.text.parserTrimmed)
            }.joined(separator: ", "),
            confidence: .heuristic,
            evidence: source.evidence(
                ruleIDs: ["publication-place.trailing-position.v1"],
                correctedRanges: segments.map(\.correctedRange),
                explanationKey: "parser.publication-place"
            )
        )
    }

    private func looksLikeTitleContinuation(_ value: String) -> Bool {
        let normalized = SearchNormalizer.normalize(value)
        return normalized.hasSuffix(" de") || normalized.hasSuffix(" of") ||
            normalized.hasPrefix("en francais") ||
            normalized == "the" || normalized == "le" || normalized == "la" || normalized == "les"
    }

    private func isConsumed(
        _ segment: ParsedSegment,
        roleMatches: [ParsingMatch],
        publisher: [Range<Int>],
        collection: [Range<Int>],
        tail: [Range<Int>]
    ) -> Bool {
        (roleMatches.map(\.correctedRange) + publisher + collection + tail)
            .contains { $0.overlaps(segment.correctedRange) }
    }

    private func originalCorrectedRange(for text: String, in value: String) -> Range<Int>? {
        value.range(of: text, options: [.caseInsensitive, .diacriticInsensitive])
            .map(value.characterOffsetRange)
    }

    private func unique<Value: Hashable>(_ values: [Value]) -> [Value] {
        var seen = Set<Value>()
        return values.filter { seen.insert($0).inserted }
    }
}

private struct CitationPatterns: @unchecked Sendable {
    static let shared = CitationPatterns()

    let leadingQuoted = try! NSRegularExpression(pattern: #"^[\"“]([^\"”]+)[\"”]"#)
    let frenchItalian = try! NSRegularExpression(pattern: #"(?i)en\s+fran[cç]ais\s+et\s+en\s+italien"#)
    let explicitFrench = try! NSRegularExpression(pattern: #"(?i)en\s+fran[cç]ais\b"#)
    let englishTranslation = try! NSRegularExpression(pattern: #"(?i)(?:english\s+translation|translated)\s+by"#)
    let selectedWorks = try! NSRegularExpression(
        pattern: #"(?i)^([\p{L}.'’\-]+)\s+((?:Œuvres|Oeuvres)\s+choisies.*?)[, ]+\s*par\s+([^,]+)"#
    )
    let authorCredential = try! NSRegularExpression(
        pattern: #"(?i)^(.+?)\s+de\s+l['’](?:acad[eé]mie|institut|soci[eé]t[eé])\b"#
    )
    let responsibilityBoundary = try! NSRegularExpression(
        pattern: #"(?i)\s+(?:foreword\s+by|with\s+maps\s+by|assisted\s+by|introduction\s+de|pr[eé]face\s+de|[eé]ditions?|[eé]d\.|librairie|presses?|collection|tome\s+\d+|\d+\s+vols?|(?:1[4-9]\d{2}|20\d{2})\b|\d{1,4}\s*p)"#
    )
    let personSeparator = try! NSRegularExpression(pattern: #"\s+(?:et|and|&)\s+"#, options: .caseInsensitive)
    let personShape = try! NSRegularExpression(
        pattern: #"^(?:[\p{Lu}][\p{L}'’\-]+|[\p{Lu}]\.|[A-Z]\.)(?:\s+(?:[\p{Lu}][\p{L}'’\-]+|[\p{Lu}]\.|[A-Z]\.|Jr|Sr)){1,6}$"#
    )
    let fourDigitYear = try! NSRegularExpression(pattern: #"\d{4}"#)
    let personStopWord = try! NSRegularExpression(
        pattern: #"(?i)\b(?:the|le|la|les|of|de|du|des|house|histoire|collection|press|editions?)\b"#
    )
}
