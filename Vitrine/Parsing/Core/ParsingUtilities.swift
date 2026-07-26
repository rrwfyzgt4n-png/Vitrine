import Foundation

struct ParsingMatch: Sendable {
    let rule: ParsingRuleDefinition
    let fullText: String
    let correctedRange: Range<Int>
    let groups: [String]
    let groupRanges: [Range<Int>?]
}

extension CompiledParsingRule {
    func matches(in value: String) -> [ParsingMatch] {
        regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap { result in
            guard let stringRange = Range(result.range, in: value) else { return nil }
            let prefix = String(value[..<stringRange.lowerBound])
            let blocked = negativeGuards.contains { guardRegex in
                guardRegex.firstMatch(
                    in: prefix,
                    range: NSRange(prefix.startIndex..., in: prefix)
                ) != nil
            }
            guard !blocked else { return nil }
            let groups = (1..<result.numberOfRanges).map { index -> String in
                guard result.range(at: index).location != NSNotFound,
                      let range = Range(result.range(at: index), in: value) else { return "" }
                return String(value[range])
            }
            let groupRanges = (1..<result.numberOfRanges).map { index -> Range<Int>? in
                guard result.range(at: index).location != NSNotFound,
                      let range = Range(result.range(at: index), in: value) else { return nil }
                return value.characterOffsetRange(for: range)
            }
            return ParsingMatch(
                rule: definition,
                fullText: String(value[stringRange]),
                correctedRange: value.characterOffsetRange(for: stringRange),
                groups: groups,
                groupRanges: groupRanges
            )
        }
    }
}

extension ParsingSource {
    func evidence(
        ruleIDs: [String],
        correctedRanges: [Range<Int>],
        explanationKey: String
    ) -> ParsingEvidence {
        let sourceSpans = correctedRanges.compactMap(originalRange)
        let correctionIDs: [String] = appliedCorrections.compactMap { correction -> String? in
            guard sourceSpans.contains(where: {
                guard let correctedOriginal = correction.originalSourceRange else { return false }
                return $0.overlaps(correctedOriginal)
            }) else { return nil }
            return correction.ruleID
        }
        return ParsingEvidence(
            ruleIDs: ruleIDs,
            originalSourceSpans: sourceSpans,
            appliedCorrectionIDs: Array(Set(correctionIDs)).sorted(),
            explanationKey: explanationKey
        )
    }
}

extension String {
    var parserTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;:\"“”")))
    }
}
