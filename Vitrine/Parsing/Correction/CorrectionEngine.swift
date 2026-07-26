import Foundation

struct CorrectionEngine: Sendable {
    let rules: [CompiledCorrectionRule]

    func correct(_ sourceTitle: String) -> ParsingSource {
        let original = sourceTitle
        var mapped = Array(original).enumerated().flatMap { offset, character -> [MappedCharacter] in
            String(character).precomposedStringWithCanonicalMapping.map {
                MappedCharacter(value: $0, originalRange: offset..<(offset + 1))
            }
        }
        var applied: [(id: String, originalRange: Range<Int>?)] = []

        removeLeadingOrdinal(from: &mapped)
        collapseWhitespace(in: &mapped)
        for rule in rules {
            let matches = matchRanges(for: rule, in: string(from: mapped))
            for range in matches.sorted(by: { $0.lowerBound > $1.lowerBound }) {
                let sourceRange = coveringOriginalRange(in: mapped, range: range)
                replace(range, with: rule.definition.replacement, in: &mapped, sourceRange: sourceRange)
                applied.append((rule.definition.id, sourceRange))
            }
        }
        collapseWhitespace(in: &mapped)
        trimWhitespace(in: &mapped)

        let corrected = string(from: mapped)
        let map = SourceOffsetMap(
            characterRanges: mapped.map(\.originalRange),
            originalCharacterCount: original.count
        )
        let appliedCorrections = applied.reversed().compactMap { entry -> AppliedCorrection? in
            guard let correctedRange = correctedRange(
                for: entry.originalRange,
                in: mapped
            ) else { return nil }
            return AppliedCorrection(
                ruleID: entry.id,
                correctedRange: correctedRange,
                originalSourceRange: entry.originalRange
            )
        }
        return ParsingSource(
            original: original,
            corrected: corrected,
            sourceMap: map,
            appliedCorrections: appliedCorrections
        )
    }

    private func matchRanges(for rule: CompiledCorrectionRule, in value: String) -> [Range<Int>] {
        switch rule.definition.matchMode {
        case "regular-expression":
            guard let regex = rule.regex else { return [] }
            return regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap {
                Range($0.range, in: value).map(value.characterOffsetRange)
            }
        default:
            var result: [Range<Int>] = []
            var searchRange = value.startIndex..<value.endIndex
            while let range = value.range(
                of: rule.definition.match,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchRange
            ) {
                result.append(value.characterOffsetRange(for: range))
                searchRange = range.upperBound..<value.endIndex
            }
            return result
        }
    }

    private func removeLeadingOrdinal(from mapped: inout [MappedCharacter]) {
        let value = string(from: mapped)
        guard let match = CorrectionPatterns.leadingOrdinal.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ), let range = Range(match.range, in: value) else { return }
        mapped.removeSubrange(value.characterOffsetRange(for: range))
    }

    private func collapseWhitespace(in mapped: inout [MappedCharacter]) {
        var result: [MappedCharacter] = []
        var index = 0
        while index < mapped.count {
            guard mapped[index].value.isWhitespace else {
                result.append(mapped[index])
                index += 1
                continue
            }
            let start = index
            while index < mapped.count, mapped[index].value.isWhitespace { index += 1 }
            result.append(MappedCharacter(
                value: " ",
                originalRange: coveringOriginalRange(in: mapped, range: start..<index) ?? 0..<0
            ))
        }
        mapped = result
    }

    private func trimWhitespace(in mapped: inout [MappedCharacter]) {
        while mapped.first?.value.isWhitespace == true { mapped.removeFirst() }
        while mapped.last?.value.isWhitespace == true { mapped.removeLast() }
    }

    private func replace(
        _ range: Range<Int>,
        with replacement: String,
        in mapped: inout [MappedCharacter],
        sourceRange: Range<Int>?
    ) {
        let replacementRange = sourceRange ?? {
            let anchor = range.lowerBound < mapped.count
                ? mapped[range.lowerBound].originalRange.lowerBound
                : mapped.last?.originalRange.upperBound ?? 0
            return anchor..<anchor
        }()
        mapped.replaceSubrange(range, with: replacement.map {
            MappedCharacter(value: $0, originalRange: replacementRange)
        })
    }

    private func correctedRange(
        for originalRange: Range<Int>?,
        in mapped: [MappedCharacter]
    ) -> Range<Int>? {
        guard let originalRange else { return nil }
        let indexes = mapped.indices.filter { mapped[$0].originalRange.overlaps(originalRange) }
        guard let first = indexes.first, let last = indexes.last else { return nil }
        return first..<(last + 1)
    }

    private func coveringOriginalRange(
        in mapped: [MappedCharacter],
        range: Range<Int>
    ) -> Range<Int>? {
        let ranges = mapped[range].map(\.originalRange).filter { !$0.isEmpty }
        guard let lower = ranges.map(\.lowerBound).min(),
              let upper = ranges.map(\.upperBound).max() else { return nil }
        return lower..<upper
    }

    private func string(from mapped: [MappedCharacter]) -> String {
        String(mapped.map(\.value))
    }

    private struct MappedCharacter {
        let value: Character
        let originalRange: Range<Int>
    }
}

private enum CorrectionPatterns {
    static let leadingOrdinal = try! NSRegularExpression(pattern: #"^\s*\d+\)\s*"#)
}
