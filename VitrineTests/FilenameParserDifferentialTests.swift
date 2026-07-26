import Foundation
import XCTest
@testable import Vitrine

final class FilenameParserDifferentialTests: XCTestCase {
    func testPortableGoldenCorpusHasNoUnapprovedValueDifferences() throws {
        let fixtures = try loadFixtures()
        let harness = FilenameParserDifferentialHarness()
        var failures: [String] = []

        for fixture in fixtures {
            let report = harness.compare(fixture.sourceTitle)
            for difference in report.valueDifferences {
                guard fixture.approvedValueDifferences[difference.field.rawValue] == nil else { continue }
                failures.append(
                    "\(difference.field.rawValue): \(difference.legacy.value ?? "nil") -> \(difference.v2.value ?? "nil")"
                )
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testMountedCorpusAuditReportsAllDifferencesAndValidatesSpans() throws {
        let folder = URL(fileURLWithPath: "/Volumes/FastData/Téléchargements/libcat", isDirectory: true)
        guard FileManager.default.fileExists(atPath: folder.path) else {
            throw XCTSkip("The user's removable-volume corpus is not mounted")
        }
        let filenames = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        )
            .filter { ["jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
        let harness = FilenameParserDifferentialHarness()
        var recordsWithDifferences = 0
        var fieldCounts: [FilenameSuggestionField: Int] = [:]
        var unresolvedCount = 0
        var unresolvedRecords: [String] = []
        var changedRecords: [String] = []

        for source in filenames {
            let report = harness.compare(source)
            if !report.valueDifferences.isEmpty {
                recordsWithDifferences += 1
                changedRecords.append(
                    "\(source) => " + report.valueDifferences.map {
                        "\($0.field.rawValue): \($0.legacy.value ?? "nil") -> \($0.v2.value ?? "nil")"
                    }.joined(separator: " | ")
                )
            }
            for difference in report.valueDifferences {
                fieldCounts[difference.field, default: 0] += 1
            }
            unresolvedCount += report.unresolvedSegments.count
            if !report.unresolvedSegments.isEmpty {
                unresolvedRecords.append(
                    "\(source) => \(report.unresolvedSegments.map(\.text).joined(separator: " | ")) " +
                        "[publisher=\(report.comparisons.first(where: { $0.field == .publisher })?.v2.value ?? "nil")]"
                )
            }
            for comparison in report.comparisons {
                if let span = comparison.v2.sourceSpan {
                    XCTAssertGreaterThanOrEqual(span.lowerBound, 0)
                    XCTAssertLessThanOrEqual(span.upperBound, source.count)
                }
            }
        }

        print(
            "VITRINE_PARSER_AUDIT records=\(filenames.count) changed_records=\(recordsWithDifferences) " +
                "unresolved=\(unresolvedCount) field_differences=\(fieldCounts)"
        )
        for record in unresolvedRecords {
            print("VITRINE_PARSER_UNRESOLVED \(record)")
        }
        for record in changedRecords {
            print("VITRINE_PARSER_DIFF \(record)")
        }
        XCTAssertEqual(filenames.count, 67)
    }

    func testV2IsDeterministicUnderConcurrentLoad() async {
        let source = "Japon, Le, Dictionnaire et civilisation, par Louis Frédéric, Éditions Robert Laffont, 1996 1419p"
        let parser = FilenameMetadataParser(engine: .v2)
        let expected = parser.suggestions(from: source)

        await withTaskGroup(of: FilenameMetadataSuggestion.self) { group in
            for _ in 0..<200 {
                group.addTask { parser.suggestions(from: source) }
            }
            for await result in group {
                XCTAssertEqual(result, expected)
            }
        }
    }

    func testOldAndNewFiveThousandRecordMetrics() throws {
        let sources = try loadFixtures().map(\.sourceTitle)
        let legacy = FilenameMetadataParser(engine: .legacy)
        let v2 = FilenameMetadataParser(engine: .v2)
        _ = legacy.suggestions(from: sources[0])
        _ = v2.suggestions(from: sources[0])

        let legacyStart = ContinuousClock.now
        for index in 0..<5_000 {
            _ = legacy.suggestions(from: sources[index % sources.count])
        }
        let legacyDuration = legacyStart.duration(to: .now)
        let v2Start = ContinuousClock.now
        for index in 0..<5_000 {
            _ = v2.suggestions(from: sources[index % sources.count])
        }
        let v2Duration = v2Start.duration(to: .now)

        print("VITRINE_PARSER_DIFFERENTIAL_METRIC legacy=\(legacyDuration) v2=\(v2Duration)")
    }

    private func loadFixtures() throws -> [GoldenFixture] {
        let candidates = [
            Bundle(for: Self.self).url(
                forResource: "ParserGoldenCorpus",
                withExtension: "json",
                subdirectory: "Fixtures"
            ),
            Bundle(for: Self.self).url(forResource: "ParserGoldenCorpus", withExtension: "json"),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            XCTFail("Missing ParserGoldenCorpus.json")
            return []
        }
        return try JSONDecoder().decode([GoldenFixture].self, from: Data(contentsOf: url))
    }
}

private struct GoldenFixture: Decodable {
    let sourceTitle: String
    let approvedValueDifferences: [String: String]
}
