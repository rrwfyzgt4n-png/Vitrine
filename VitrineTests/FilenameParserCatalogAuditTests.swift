import Foundation
import XCTest
@testable import Vitrine

final class FilenameParserCatalogAuditTests: XCTestCase {
    func testReviewedFilenameMetadataAgainstCompleteCatalog() throws {
        guard let rawPath = ProcessInfo.processInfo.environment["VITRINE_PARSER_CATALOG_PATH"] else {
            throw XCTSkip("Set VITRINE_PARSER_CATALOG_PATH to run this audit against a reviewed catalog")
        }
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw XCTSkip("Set VITRINE_PARSER_CATALOG_PATH to run this audit against a reviewed catalog")
        }
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("The reviewed filename catalog is unavailable")
        }

        let markdown = try String(contentsOfFile: path, encoding: .utf8)
        let catalog = try CatalogMarkdownParser().parse(markdown).snapshot
        XCTAssertEqual(catalog.items.count, 66)

        let parser = FilenameMetadataParser(engine: .v2)
        var matchingRecords = 0
        var mismatches: [CatalogAuditMismatch] = []
        var unresolvedCount = 0
        var unresolvedSegments: [CatalogAuditUnresolved] = []

        for item in catalog.items {
            let parsed = parser.detailedParse(from: item.source.sourceTitle)
            let suggestion = parsed.suggestion
            let recordMismatches: [CatalogAuditMismatch] = FilenameSuggestionField.allCases.compactMap { field in
                let parserValue = parserSnapshot(field: field, suggestion: suggestion)
                let catalogValue = catalogSnapshot(field: field, metadata: item.bibliography)
                guard normalized(parserValue) != normalized(catalogValue) else { return nil }
                return CatalogAuditMismatch(
                    sourceTitle: item.source.sourceTitle,
                    field: field.rawValue,
                    parserValue: parserValue,
                    catalogValue: catalogValue
                )
            }
            if recordMismatches.isEmpty {
                matchingRecords += 1
            } else {
                mismatches.append(contentsOf: recordMismatches)
            }

            unresolvedCount += parsed.draft.unresolvedSegments.count
            for unresolved in parsed.draft.unresolvedSegments {
                unresolvedSegments.append(.init(
                    sourceTitle: item.source.sourceTitle,
                    text: unresolved.text
                ))
                XCTAssertGreaterThanOrEqual(unresolved.originalSourceSpan.lowerBound, 0)
                XCTAssertLessThanOrEqual(
                    unresolved.originalSourceSpan.upperBound,
                    item.source.sourceTitle.count
                )
            }
            for field in FilenameSuggestionField.allCases {
                guard let span = suggestionSpan(field: field, suggestion: suggestion) else { continue }
                XCTAssertGreaterThanOrEqual(span.lowerBound, 0)
                XCTAssertLessThanOrEqual(span.upperBound, item.source.sourceTitle.count)
            }
        }

        print(
            "VITRINE_CATALOG_AUDIT records=\(catalog.items.count) " +
                "matching_records=\(matchingRecords) mismatches=\(mismatches.count) " +
                "unresolved=\(unresolvedCount)"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        for mismatch in mismatches {
            let data = try encoder.encode(mismatch)
            print("VITRINE_CATALOG_MISMATCH \(String(decoding: data, as: UTF8.self))")
        }
        for unresolved in unresolvedSegments {
            let data = try encoder.encode(unresolved)
            print("VITRINE_CATALOG_UNRESOLVED \(String(decoding: data, as: UTF8.self))")
        }
    }

    private func parserSnapshot(
        field: FilenameSuggestionField,
        suggestion: FilenameMetadataSuggestion
    ) -> String? {
        switch field {
        case .title: suggestion.title?.value
        case .subtitle: suggestion.subtitle?.value
        case .authors: list(suggestion.authors?.value)
        case .translators: list(suggestion.translators?.value)
        case .contributors: contributors(suggestion.contributors?.value)
        case .publisher: suggestion.publisher?.value
        case .collectionName: suggestion.collectionName?.value
        case .collectionNumber: suggestion.collectionNumber?.value
        case .publicationPlace: suggestion.publicationPlace?.value
        case .publicationDate: suggestion.publicationDate?.value
        case .originalPublicationDate: suggestion.originalPublicationDate?.value
        case .editionDescription: suggestion.editionDescription?.value
        case .volumeDescription: suggestion.volumeDescription?.value
        case .languageCodes: list(suggestion.languageCodes?.value)
        case .originalLanguageCode: suggestion.originalLanguageCode?.value
        case .pageCount: suggestion.pageCount.map { String($0.value) }
        case .paginationStatus: suggestion.paginationStatus?.value.rawValue
        case .physicalAttributes: list(suggestion.physicalAttributes?.value.map(\.rawValue))
        case .descriptiveNotes: suggestion.descriptiveNotes?.value
        }
    }

    private func catalogSnapshot(
        field: FilenameSuggestionField,
        metadata: BibliographicMetadata
    ) -> String? {
        switch field {
        case .title: metadata.title
        case .subtitle: metadata.subtitle
        case .authors: list(metadata.authors)
        case .translators: list(metadata.translators)
        case .contributors: contributors(metadata.contributors)
        case .publisher: metadata.publisher
        case .collectionName: metadata.collectionName
        case .collectionNumber: metadata.collectionNumber
        case .publicationPlace: metadata.publicationPlace
        case .publicationDate: metadata.publicationDate
        case .originalPublicationDate: metadata.originalPublicationDate
        case .editionDescription: metadata.editionDescription
        case .volumeDescription: metadata.volumeDescription
        case .languageCodes: list(
            [metadata.languageCode].compactMap { $0 } + metadata.additionalLanguageCodes
        )
        case .originalLanguageCode: metadata.originalLanguageCode
        case .pageCount: metadata.pageCount.map(String.init)
        case .paginationStatus: metadata.paginationStatus?.rawValue
        case .physicalAttributes: list(metadata.physicalAttributes.map(\.rawValue))
        case .descriptiveNotes: metadata.description
        }
    }

    private func suggestionSpan(
        field: FilenameSuggestionField,
        suggestion: FilenameMetadataSuggestion
    ) -> Range<Int>? {
        switch field {
        case .title: suggestion.title?.sourceSpan
        case .subtitle: suggestion.subtitle?.sourceSpan
        case .authors: suggestion.authors?.sourceSpan
        case .translators: suggestion.translators?.sourceSpan
        case .contributors: suggestion.contributors?.sourceSpan
        case .publisher: suggestion.publisher?.sourceSpan
        case .collectionName: suggestion.collectionName?.sourceSpan
        case .collectionNumber: suggestion.collectionNumber?.sourceSpan
        case .publicationPlace: suggestion.publicationPlace?.sourceSpan
        case .publicationDate: suggestion.publicationDate?.sourceSpan
        case .originalPublicationDate: suggestion.originalPublicationDate?.sourceSpan
        case .editionDescription: suggestion.editionDescription?.sourceSpan
        case .volumeDescription: suggestion.volumeDescription?.sourceSpan
        case .languageCodes: suggestion.languageCodes?.sourceSpan
        case .originalLanguageCode: suggestion.originalLanguageCode?.sourceSpan
        case .pageCount: suggestion.pageCount?.sourceSpan
        case .paginationStatus: suggestion.paginationStatus?.sourceSpan
        case .physicalAttributes: suggestion.physicalAttributes?.sourceSpan
        case .descriptiveNotes: suggestion.descriptiveNotes?.sourceSpan
        }
    }

    private func list(_ values: [String]?) -> String? {
        guard let values, !values.isEmpty else { return nil }
        return values.joined(separator: " | ")
    }

    private func contributors(_ values: [BibliographicContributor]?) -> String? {
        guard let values, !values.isEmpty else { return nil }
        return values.map {
            "\($0.name)[\($0.roles.map(\.rawValue).joined(separator: ","))]"
        }.joined(separator: " | ")
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.precomposedStringWithCanonicalMapping
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

private struct CatalogAuditMismatch: Encodable {
    let sourceTitle: String
    let field: String
    let parserValue: String?
    let catalogValue: String?
}

private struct CatalogAuditUnresolved: Encodable {
    let sourceTitle: String
    let text: String
}
