import Foundation

struct TopLevelSegmenter: Sendable {
    func segments(in source: ParsingSource) -> [ParsedSegment] {
        let characters = Array(source.corrected)
        var result: [ParsedSegment] = []
        var start = 0
        var parenthesesDepth = 0
        var activeQuote: Character?

        func appendSegment(end: Int) {
            var lower = start
            var upper = end
            while lower < upper, characters[lower].isWhitespace { lower += 1 }
            while upper > lower, characters[upper - 1].isWhitespace { upper -= 1 }
            guard lower < upper, let original = source.originalRange(for: lower..<upper) else { return }
            result.append(ParsedSegment(
                text: String(characters[lower..<upper]),
                correctedRange: lower..<upper,
                originalRange: original
            ))
        }

        for (offset, character) in characters.enumerated() {
            if ["\"", "“", "”"].contains(character) {
                if activeQuote == nil {
                    activeQuote = character
                } else {
                    activeQuote = nil
                }
                continue
            }
            if activeQuote != nil {
                if character == "," {
                    let suffix = String(characters[(offset + 1)...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if SegmenterPatterns.recoveryBoundary.firstMatch(
                        in: suffix,
                        range: NSRange(suffix.startIndex..., in: suffix)
                    ) != nil {
                        activeQuote = nil
                        appendSegment(end: offset)
                        start = offset + 1
                    }
                }
                continue
            }
            if character == "(" {
                parenthesesDepth += 1
            } else if character == ")" {
                parenthesesDepth = max(0, parenthesesDepth - 1)
            } else if character == ",", parenthesesDepth == 0 {
                appendSegment(end: offset)
                start = offset + 1
            }
        }
        appendSegment(end: characters.count)
        return result
    }
}

private enum SegmenterPatterns {
    static let recoveryBoundary = try! NSRegularExpression(
        pattern: #"(?i)^(?:(?:par|by|translated|english translation|traduit|traduction|[eé]ditions?|[eé]d\.|librairie|presses?)\b|[^,]{1,50}\s&\s[^,]{1,50}(?:,|$))"#
    )
}
