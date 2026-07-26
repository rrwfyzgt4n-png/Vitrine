import Foundation

struct TitleResolution: Sendable {
    let title: ParsedTitleCandidate
    let subtitle: FieldCandidate<String>?
}

struct TitleInversionResolver: Sendable {
    let configuration: ParsingConfiguration
    private let patterns = TitlePatterns.shared

    func resolve(
        text: String,
        correctedRange: Range<Int>,
        source: ParsingSource
    ) -> TitleResolution {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        let pieces = splitTopLevelCommas(raw)
        let baseEvidence = source.evidence(
            ruleIDs: ["title.boundary.classified-segment.v1"],
            correctedRanges: [correctedRange],
            explanationKey: "parser.title"
        )

        var title = raw
        var subtitle: String?
        var inversion: InversionKind = .none
        var titleRule = "title.boundary.classified-segment.v1"

        if let subject = quotedSubjectTitle(raw) {
            title = "\(subject.subject): \(subject.quoted)"
            inversion = .heuristic
            titleRule = "title.subject-heading.quoted.v1"
        } else if pieces.count >= 2,
                  let article = articleValue(pieces[1]) {
            title = join(article: article, title: pieces[0])
            subtitle = pieces.dropFirst(2).joined(separator: ", ").parserTrimmed
            inversion = .mechanical
            titleRule = "inversion.article.v1"
        } else if pieces.count >= 2,
                  let article = articleValue(pieces.last ?? "") {
            title = join(article: article, title: pieces[0])
            subtitle = pieces.dropFirst().dropLast().joined(separator: ", ").parserTrimmed
            inversion = .mechanical
            titleRule = "inversion.article.v1"
        } else if pieces.count >= 2,
                  let reordered = connectiveTitle(subject: pieces[0], descriptor: pieces[1]) {
            title = reordered
            subtitle = pieces.dropFirst(2).joined(separator: ", ").parserTrimmed
            inversion = .heuristic
            titleRule = "inversion.trailing-connective.v1"
        } else if pieces.count >= 2,
                  let guide = descriptorEndingInArticle(subject: pieces[0], descriptor: pieces[1]) {
            title = guide
            subtitle = pieces.dropFirst(2).joined(separator: ", ").parserTrimmed
            inversion = .heuristic
            titleRule = "inversion.descriptor-ending-article.v1"
        } else if pieces.count >= 2,
                  let person = surnameFirstTitle(surname: pieces[0], remainder: pieces[1]) {
            title = person
            subtitle = pieces.dropFirst(2).joined(separator: ", ").parserTrimmed
            inversion = .heuristic
            titleRule = "inversion.person-name.v1"
        } else if pieces.count == 2,
                  SearchNormalizer.normalize(pieces[1]).hasPrefix("the life story of ") {
            title = pieces[0]
            subtitle = pieces[1]
            titleRule = "title.subtitle.descriptive-phrase.v1"
        } else if pieces.count >= 2,
                  pieces[1].trimmingCharacters(in: .whitespaces).hasPrefix("-") {
            title = pieces[0]
            subtitle = pieces.dropFirst().joined(separator: ", ")
                .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-")))
            titleRule = "title.subtitle.leading-hyphen.v1"
        } else if let subject = subjectAppendedToSubtitle(pieces) {
            title = subject
            inversion = .heuristic
            titleRule = "inversion.subject-heading.v1"
        } else if let quoted = quotedSubtitle(raw) {
            title = quoted.title
            subtitle = quoted.subtitle
            titleRule = "title.subtitle.quoted.v1"
        } else if let hyphen = hyphenSubtitle(raw) {
            title = hyphen.title
            subtitle = hyphen.subtitle
            titleRule = "title.subtitle.hyphen.v1"
        }

        let titleEvidence = ParsingEvidence(
            ruleIDs: unique(baseEvidence.ruleIDs + [titleRule]),
            originalSourceSpans: baseEvidence.originalSourceSpans,
            appliedCorrectionIDs: baseEvidence.appliedCorrectionIDs,
            explanationKey: "parser.title"
        )
        let parsed = ParsedTitleCandidate(
            displayForm: title.parserTrimmed,
            sourceFilingForm: raw,
            inversionKind: inversion,
            evidence: titleEvidence
        )
        let subtitleCandidate = subtitle.flatMap { clean -> FieldCandidate<String>? in
            let value = clean.trimmingCharacters(
                in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”,-"))
            )
            guard !value.isEmpty else { return nil }
            return FieldCandidate(
                value: value,
                confidence: inversion == .mechanical ? .mechanical : .heuristic,
                evidence: ParsingEvidence(
                    ruleIDs: [titleRule],
                    originalSourceSpans: baseEvidence.originalSourceSpans,
                    appliedCorrectionIDs: baseEvidence.appliedCorrectionIDs,
                    explanationKey: "parser.subtitle"
                )
            )
        }
        return TitleResolution(title: parsed, subtitle: subtitleCandidate)
    }

    private func splitTopLevelCommas(_ value: String) -> [String] {
        let characters = Array(value)
        var result: [String] = []
        var start = 0
        var quote = false
        var depth = 0
        for (offset, character) in characters.enumerated() {
            if ["\"", "“", "”"].contains(character) {
                quote.toggle()
            } else if !quote, character == "(" {
                depth += 1
            } else if !quote, character == ")" {
                depth = max(0, depth - 1)
            } else if !quote, depth == 0, character == "," {
                result.append(String(characters[start..<offset]).parserTrimmed)
                start = offset + 1
            }
        }
        result.append(String(characters[start...]).parserTrimmed)
        return result.filter { !$0.isEmpty }
    }

    private func articleValue(_ value: String) -> String? {
        for rule in configuration.rules(category: "article") {
            if !rule.matches(in: value.parserTrimmed).isEmpty {
                return rule.definition.canonicalValue ?? value.parserTrimmed
            }
        }
        return nil
    }

    private func join(article: String, title: String) -> String {
        article.hasSuffix("'") ? "\(article)\(title)" : "\(article) \(title)"
    }

    private func connectiveTitle(subject: String, descriptor: String) -> String? {
        for rule in configuration.rules(category: "trailing-connective") {
            if !rule.matches(in: descriptor).isEmpty {
                return "\(descriptor) \(subject)"
            }
        }
        return nil
    }

    private func descriptorEndingInArticle(subject: String, descriptor: String) -> String? {
        guard let match = patterns.descriptorArticle.firstMatch(
            in: descriptor,
            range: NSRange(descriptor.startIndex..., in: descriptor)
        ), match.numberOfRanges == 3,
              let prefixRange = Range(match.range(at: 1), in: descriptor),
              let articleRange = Range(match.range(at: 2), in: descriptor) else { return nil }
        let prefix = String(descriptor[prefixRange]).parserTrimmed
        let article = String(descriptor[articleRange]).lowercased()
        return "\(prefix) \(article) \(subject)"
    }

    private func surnameFirstTitle(surname: String, remainder: String) -> String? {
        guard let match = patterns.honorificName.firstMatch(
            in: remainder,
            range: NSRange(remainder.startIndex..., in: remainder)
        ), match.numberOfRanges == 3,
              let honorific = Range(match.range(at: 1), in: remainder),
              let rest = Range(match.range(at: 2), in: remainder) else { return nil }
        let words = String(remainder[rest]).split(separator: " ")
        guard let first = words.first else { return nil }
        return ([String(remainder[honorific]), String(first), surname] + words.dropFirst().map(String.init))
            .joined(separator: " ")
    }

    private func subjectAppendedToSubtitle(_ pieces: [String]) -> String? {
        guard pieces.count == 2,
              let hyphen = hyphenSubtitle(pieces[1]),
              SearchNormalizer.normalize(hyphen.subtitle).contains("story of") else { return nil }
        return "\(hyphen.title): \(hyphen.subtitle) \(pieces[0])"
    }

    private func quotedSubjectTitle(_ value: String) -> (subject: String, quoted: String)? {
        guard let match = patterns.subjectQuoted.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ), match.numberOfRanges == 3,
              let subject = Range(match.range(at: 1), in: value),
              let quoted = Range(match.range(at: 2), in: value) else { return nil }
        let subjectText = String(value[subject]).parserTrimmed
        let words = subjectText.split(separator: " ")
        guard words.count >= 2,
              words.allSatisfy({
                  $0.first?.isUppercase == true
              }) else { return nil }
        return (subjectText, String(value[quoted]).parserTrimmed)
    }

    private func quotedSubtitle(_ value: String) -> (title: String, subtitle: String)? {
        guard let match = patterns.quotedSubtitle.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ), match.numberOfRanges == 3,
              let title = Range(match.range(at: 1), in: value),
              let subtitle = Range(match.range(at: 2), in: value) else { return nil }
        return (String(value[title]).parserTrimmed, String(value[subtitle]).parserTrimmed)
    }

    private func hyphenSubtitle(_ value: String) -> (title: String, subtitle: String)? {
        guard let match = patterns.hyphenSubtitle.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ), match.numberOfRanges == 3,
              let title = Range(match.range(at: 1), in: value),
              let subtitle = Range(match.range(at: 2), in: value) else { return nil }
        return (String(value[title]).parserTrimmed, String(value[subtitle]).parserTrimmed)
    }

    private func unique<Value: Hashable>(_ values: [Value]) -> [Value] {
        var seen = Set<Value>()
        return values.filter { seen.insert($0).inserted }
    }
}

private struct TitlePatterns: @unchecked Sendable {
    static let shared = TitlePatterns()
    let descriptorArticle = try! NSRegularExpression(
        pattern: #"(?i)^(.+?)\s+(the|a|an|le|la|les|l['’]?)$"#
    )
    let honorificName = try! NSRegularExpression(pattern: #"(?i)^(Sir|Dame)\s+(.+)$"#)
    let subjectQuoted = try! NSRegularExpression(pattern: #"^([^\"“]+?)\s*[\"“]([^\"”]+)[\"”]?$"#)
    let quotedSubtitle = try! NSRegularExpression(pattern: #"^(.+?)[,\s]+[\"“]([^\"”]+)[\"”]?$"#)
    let hyphenSubtitle = try! NSRegularExpression(pattern: #"^(.+?),?\s+-\s*(.+)$"#)
}
