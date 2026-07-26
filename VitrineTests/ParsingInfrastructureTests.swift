import XCTest
@testable import Vitrine

final class ParsingInfrastructureTests: XCTestCase {
    func testBundledRulePackageLoadsAndHasStableIdentity() {
        let configuration = ParsingConfiguration.bundled

        XCTAssertEqual(configuration.manifest.schemaVersion, 1)
        XCTAssertEqual(configuration.manifest.packageVersion, "2.1.0")
        XCTAssertEqual(configuration.manifest.parserEngineVersion, "2.1.0")
        XCTAssertFalse(configuration.corrections.isEmpty)
        XCTAssertFalse(configuration.lexicalMarkers.isEmpty)
    }

    func testValidatorRejectsUnsupportedSchemaDuplicateIDsInvalidRegexAndConflicts() {
        let rule = parsingRule(id: "rule.test.v1", pattern: "title")
        let duplicate = package(
            manifest: .init(schemaVersion: 1, packageVersion: "2.1.0", parserEngineVersion: "2.1.0", resourceDigests: [:]),
            lexical: [rule, rule]
        )
        XCTAssertThrowsError(try RulePackageValidator().validate(duplicate, resources: [:], validateDigests: false)) {
            XCTAssertEqual($0 as? RulePackageError, .duplicateRuleID("rule.test.v1"))
        }

        let unsupported = package(
            manifest: .init(schemaVersion: 2, packageVersion: "2.1.0", parserEngineVersion: "2.1.0", resourceDigests: [:])
        )
        XCTAssertThrowsError(try RulePackageValidator().validate(unsupported, resources: [:], validateDigests: false)) {
            XCTAssertEqual($0 as? RulePackageError, .unsupportedSchema(2))
        }

        let invalid = package(
            manifest: .init(schemaVersion: 1, packageVersion: "2.1.0", parserEngineVersion: "2.1.0", resourceDigests: [:]),
            lexical: [parsingRule(id: "rule.invalid.v1", pattern: "(")]
        )
        XCTAssertThrowsError(try RulePackageValidator().validate(invalid, resources: [:], validateDigests: false)) {
            XCTAssertEqual($0 as? RulePackageError, .invalidRegex("rule.invalid.v1"))
        }

        let conflict = package(
            manifest: .init(schemaVersion: 1, packageVersion: "2.1.0", parserEngineVersion: "2.1.0", resourceDigests: [:]),
            lexical: [
                parsingRule(id: "rule.first.v1", pattern: "same"),
                parsingRule(id: "rule.second.v1", pattern: "same"),
            ]
        )
        XCTAssertThrowsError(try RulePackageValidator().validate(conflict, resources: [:], validateDigests: false)) {
            XCTAssertEqual($0 as? RulePackageError, .precedenceConflict("rule.first.v1", "rule.second.v1"))
        }
    }

    func testValidatorRejectsMissingResourceDigestMismatchAndContradictoryAlias() {
        let manifest = RulePackageManifest(
            schemaVersion: 1,
            packageVersion: "2.1.0",
            parserEngineVersion: "2.1.0",
            resourceDigests: [:]
        )
        XCTAssertThrowsError(
            try RulePackageValidator().validate(package(manifest: manifest), resources: [:])
        ) {
            XCTAssertEqual($0 as? RulePackageError, .missingResource("correction-rules.json"))
        }
        let wrongDigests = Dictionary(
            uniqueKeysWithValues: RulePackageLoader.resourceNames.map { ($0, Data("x".utf8)) }
        )
        XCTAssertThrowsError(
            try RulePackageValidator().validate(package(manifest: manifest), resources: wrongDigests)
        ) {
            XCTAssertEqual($0 as? RulePackageError, .digestMismatch("correction-rules.json"))
        }

        let contradictory = DecodedRulePackage(
            manifest: manifest,
            corrections: [],
            contributorMarkers: [],
            inversionMarkers: [],
            collectionMarkers: [],
            lexicalMarkers: [],
            aliases: [
                .init(id: "alias.first.v1", category: "place", match: "Paris", canonicalValue: "Paris", version: "1"),
                .init(id: "alias.second.v1", category: "place", match: "PARIS", canonicalValue: "Elsewhere", version: "1"),
            ]
        )
        XCTAssertThrowsError(
            try RulePackageValidator().validate(contradictory, resources: [:], validateDigests: false)
        ) {
            XCTAssertEqual($0 as? RulePackageError, .contradictoryAlias("PARIS"))
        }
    }

    func testCorrectionsPreserveOriginalOffsetsAcrossInsertionReplacementAndWhitespace() {
        let source = "30) A:B  libre-éc hange"
        let parsed = CorrectionEngine(rules: ParsingConfiguration.bundled.corrections).correct(source)

        XCTAssertEqual(parsed.corrected, "A: B libre-échange")
        XCTAssertEqual(parsed.originalText(in: parsed.originalRange(for: 3..<4)!), "B")
        let repairedRange = parsed.corrected.range(of: "libre-échange").map {
            parsed.corrected.characterOffsetRange(for: $0)
        }!
        XCTAssertEqual(parsed.originalText(in: parsed.originalRange(for: repairedRange)!), "libre-éc hange")
        XCTAssertTrue(parsed.appliedCorrections.map(\.ruleID).contains("correction.spacing.libre-echange.v1"))
    }

    func testSegmenterProtectsQuotedAndParenthesizedCommasAndRecoversOpenQuoteAtRoleMarker() {
        let correct = CorrectionEngine(rules: []).correct(#"Title, "subtitle, retained", Author (Jr., PhD), Publisher"#)
        XCTAssertEqual(TopLevelSegmenter().segments(in: correct).map(\.text), [
            "Title", #""subtitle, retained""#, "Author (Jr., PhD)", "Publisher",
        ])

        let malformed = CorrectionEngine(rules: []).correct(#"Subject "quoted, text, by Author, Publisher"#)
        XCTAssertEqual(TopLevelSegmenter().segments(in: malformed).map(\.text), [
            "Subject \"quoted, text", "by Author", "Publisher",
        ])
    }

    func testTailParserSupportsUndatedBarePagesAndPartialPhysicalTail() {
        let parser = FilenameMetadataParser(engine: .v2)
        let undated = parser.suggestions(from: "Album, s/d non-paginé ill")
        let bare = parser.suggestions(from: "Ancêtres, par Auteur, Éditions Exemple, 1991 211")
        let partial = parser.suggestions(from: "Title, par Auteur, Publisher, 1980 120p. ill. réparation")

        XCTAssertEqual(undated.paginationStatus?.value, .nonPaginated)
        XCTAssertEqual(undated.physicalAttributes?.value, [.illustrated])
        XCTAssertEqual(bare.pageCount?.value, 211)
        XCTAssertEqual(partial.publicationDate?.value, "1980")
        XCTAssertEqual(partial.pageCount?.value, 120)
        XCTAssertTrue(partial.descriptiveNotes?.value.contains("réparation") == true)
    }

    func testUnresolvedSegmentsArePreservedAndAllPublicSpansReferenceOriginalSource() {
        let source = "Title, par Alice Example, élément mystérieux, Éditions Exemple, Paris 2001 120p. ill"
        let parsed = FilenameMetadataParser(engine: .v2).detailedParse(from: source)

        XCTAssertTrue(parsed.draft.unresolvedSegments.contains { $0.text == "élément mystérieux" })
        for suggestion in snapshots(parsed.suggestion) {
            guard let span = suggestion.sourceSpan else {
                XCTFail("Every emitted v2 field must have an original source span")
                continue
            }
            XCTAssertGreaterThanOrEqual(span.lowerBound, 0)
            XCTAssertLessThanOrEqual(span.upperBound, source.count)
            XCTAssertEqual(suggestion.evidence, String(Array(source)[span]))
        }
    }

    func testRemainingSuggestionFieldsNameSuffixAndInversionConfidenceAreCovered() {
        let parser = FilenameMetadataParser(engine: .v2)
        let series = parser.suggestions(
            from: "bibliographie, La, par Louise-Noëlle Malclès, \"Que sais-je\" No 708 Presses Universitaires de France, 1962 (1956) 136p"
        )
        let edition = parser.suggestions(
            from: "Along the Trail with Lewis and Clark, by Barbara Fifer with maps by Joseph Mussulman, Third Edition, Farcountry Press, 2022 (2011) 120p. ill"
        )
        let suffix = parser.suggestions(
            from: "A Working Life, Alice Example Jr, Example Press, 2000 100p"
        )
        let mechanical = parser.detailedParse(
            from: "Japon, Le, par Louis Frédéric, Éditions Exemple, 1996 200p"
        )
        let heuristic = parser.detailedParse(
            from: "Drummondville, Bottin Touristique & Historique de, 1975 88p"
        )

        XCTAssertEqual(series.collectionName?.value, "Que sais-je")
        XCTAssertEqual(series.collectionNumber?.value, "708")
        XCTAssertEqual(edition.editionDescription?.value, "Third Edition")
        XCTAssertEqual(suffix.authors?.value, ["Alice Example Jr"])
        XCTAssertEqual(mechanical.draft.title?.inversionKind, .mechanical)
        XCTAssertEqual(heuristic.draft.title?.inversionKind, .heuristic)
        XCTAssertEqual(FilenameSuggestionField.allCases.count, 19)
    }

    private func parsingRule(id: String, pattern: String) -> ParsingRuleDefinition {
        .init(
            id: id,
            category: "test",
            pattern: pattern,
            precedence: 1,
            specificity: 1,
            confidence: .mechanical,
            negativeGuards: [],
            version: "1"
        )
    }

    private func package(
        manifest: RulePackageManifest,
        lexical: [ParsingRuleDefinition] = []
    ) -> DecodedRulePackage {
        .init(
            manifest: manifest,
            corrections: [],
            contributorMarkers: [],
            inversionMarkers: [],
            collectionMarkers: [],
            lexicalMarkers: lexical,
            aliases: []
        )
    }

    private func snapshots(_ suggestion: FilenameMetadataSuggestion) -> [ParserFieldSnapshot] {
        return FilenameSuggestionField.allCases.compactMap { field in
            switch field {
            case .title: suggestion.title.map(snapshot)
            case .subtitle: suggestion.subtitle.map(snapshot)
            case .authors: suggestion.authors.map(snapshot)
            case .translators: suggestion.translators.map(snapshot)
            case .contributors: suggestion.contributors.map(snapshot)
            case .publisher: suggestion.publisher.map(snapshot)
            case .collectionName: suggestion.collectionName.map(snapshot)
            case .collectionNumber: suggestion.collectionNumber.map(snapshot)
            case .publicationPlace: suggestion.publicationPlace.map(snapshot)
            case .publicationDate: suggestion.publicationDate.map(snapshot)
            case .originalPublicationDate: suggestion.originalPublicationDate.map(snapshot)
            case .editionDescription: suggestion.editionDescription.map(snapshot)
            case .volumeDescription: suggestion.volumeDescription.map(snapshot)
            case .languageCodes: suggestion.languageCodes.map(snapshot)
            case .originalLanguageCode: suggestion.originalLanguageCode.map(snapshot)
            case .pageCount: suggestion.pageCount.map(snapshot)
            case .paginationStatus: suggestion.paginationStatus.map(snapshot)
            case .physicalAttributes: suggestion.physicalAttributes.map(snapshot)
            case .descriptiveNotes: suggestion.descriptiveNotes.map(snapshot)
            }
        }
    }

    private func snapshot<Value: Equatable & Sendable>(_ value: SuggestedValue<Value>) -> ParserFieldSnapshot {
        .init(
            value: "present",
            confidence: value.confidence,
            evidence: value.evidence,
            sourceSpan: value.sourceSpan
        )
    }
}
