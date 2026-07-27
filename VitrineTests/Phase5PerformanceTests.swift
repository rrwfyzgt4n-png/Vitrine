import XCTest
@testable import Vitrine

final class Phase5PerformanceTests: XCTestCase {
    @MainActor
    func testRepeatedSearchQueriesOverFiveThousandItemsPreserveResultsAfterNonTitleEdit() {
        let items = (0..<5_000).map { number in
            CatalogItem(
                id: deterministicUUID(number),
                source: SourceFileMetadata(relativePath: "Cover-\(number).jpg"),
                bibliography: BibliographicMetadata(
                    title: String(format: "Book %04d", number),
                    authors: number.isMultiple(of: 100) ? ["Needle Author"] : ["Other Author"],
                    metadataConfirmedByUser: true
                )
            )
        }
        let store = CatalogStore()
        store.catalog = CatalogSnapshot(name: "Search Scale", items: items)
        store.sortOption = .titleAscending
        store.searchText = "needle author"
        let expected = store.visibleItems.map(\.id)

        for _ in 0..<20 {
            XCTAssertEqual(store.visibleItems.map(\.id), expected)
        }

        var changed = store.catalog!
        changed.items[1].bibliography.publisher = "A non-title edit"
        store.catalog = changed

        XCTAssertEqual(store.visibleItems.map(\.id), expected)
        store.searchText = ""
        XCTAssertEqual(store.visibleItems.map(\.id), items.map(\.id))
    }

    func testFilenameParserFiveThousandRecordMetric() {
        let filenames = [
            "Japon, Le, Dictionnaire et civilisation, par Louis Frédéric, Éditions Robert Laffont, 1996 1419p",
            "Lieux et monuments historiques des Cantons de l'Est et des Bois-Francs, vol 7 par Rodolphe Fournier Éditions Paulines 1978 277p. ill. plus une carte",
            "Hammonds of Redcliffe, The, edited by Carol Bleser, Oxford University Press, 1981 421p. ill",
            "La nature du prince, récit de Roger Peyrefitte, Le Livre de Poche, Flammarion 1967 (1963) 190p",
            "Sissi, impératrice d'Autriche, par Élisabeth Burnat, Le Livre de Poche, 1976 (1957) 253p",
        ]
        let parser = FilenameMetadataParser()
        let started = CFAbsoluteTimeGetCurrent()
        var parsedCount = 0
        for index in 0..<5_000 {
            if parser.suggestions(from: filenames[index % filenames.count]).title != nil {
                parsedCount += 1
            }
        }
        let milliseconds = (CFAbsoluteTimeGetCurrent() - started) * 1_000
        print("VITRINE_PHASE5_PARSER_METRIC records=5000 milliseconds=\(milliseconds)")
        XCTAssertEqual(parsedCount, 5_000)
    }

    func testFilenameParserIsDeterministicUnderConcurrentLoad() async {
        let source = "Japon, Le, Dictionnaire et civilisation, par Louis Frédéric, Éditions Robert Laffont, 1996 1419p"
        let expected = FilenameMetadataParser().suggestions(from: source)

        await withTaskGroup(of: FilenameMetadataSuggestion.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    FilenameMetadataParser().suggestions(from: source)
                }
            }
            for await result in group {
                XCTAssertEqual(result, expected)
            }
        }
    }

    @MainActor
    func testFiveThousandRecordDiffMatchesLegacyBehaviorAndReportsMetric() {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let items = (0..<5_000).map { number in
            CatalogItem(
                id: deterministicUUID(number),
                source: SourceFileMetadata(
                    relativePath: "Cover-\(number).jpg",
                    portableFingerprint: "fingerprint-\(number)",
                    fileModificationDate: date
                ),
                dateAdded: date,
                dateModified: date
            )
        }
        let snapshot = CatalogSnapshot(
            name: "Scale",
            updatedAt: date,
            items: items
        )
        var operations: [CatalogReconciliationOperation] = items.map { item in
            .updateFinderComment(
                id: item.id,
                expected: revision(item),
                comment: "Refreshed"
            )
        }
        operations.append(contentsOf: items.enumerated().compactMap { index, item in
            index.isMultiple(of: 5)
                ? .removeRecord(id: item.id, expected: revision(item))
                : nil
        })
        for number in 5_000..<5_100 {
            operations.append(.addRecord(NewCatalogRecord(item: CatalogItem(
                id: deterministicUUID(number),
                source: SourceFileMetadata(relativePath: "Cover-\(number).jpg")
            ))))
        }
        let diff = CatalogReconciliationDiff(
            baseCatalogID: snapshot.catalogID,
            baseCatalogUpdatedAt: snapshot.updatedAt,
            sourceFolderValidated: true,
            scannedSources: [],
            operations: operations,
            completedEnumeration: true,
            warnings: []
        )

        let legacyStart = CFAbsoluteTimeGetCurrent()
        let legacy = legacyApply(diff: diff, to: snapshot, allowRemovals: true)
        let legacyMilliseconds = (CFAbsoluteTimeGetCurrent() - legacyStart) * 1_000
        let optimizedStart = CFAbsoluteTimeGetCurrent()
        let optimized = CatalogStore().apply(diff: diff, to: snapshot, allowRemovals: true)
        let optimizedMilliseconds = (CFAbsoluteTimeGetCurrent() - optimizedStart) * 1_000

        print(
            "VITRINE_PHASE5_RECONCILIATION_METRIC records=5000 " +
                "legacy_ms=\(legacyMilliseconds) optimized_ms=\(optimizedMilliseconds)"
        )
        XCTAssertEqual(optimized, legacy)
        XCTAssertLessThan(optimizedMilliseconds, legacyMilliseconds)
    }

    private func deterministicUUID(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0005-%012d", number))!
    }

    private func revision(_ item: CatalogItem) -> SourceRevision {
        SourceRevision(
            relativePath: item.source.relativePath,
            portableFingerprint: item.source.portableFingerprint,
            fileModificationDate: item.source.fileModificationDate
        )
    }

    private func legacyApply(
        diff: CatalogReconciliationDiff,
        to snapshot: CatalogSnapshot,
        allowRemovals: Bool
    ) -> CatalogSnapshot {
        var result = snapshot
        for operation in diff.operations {
            switch operation {
            case .addRecord(let record):
                guard !result.items.contains(where: {
                    $0.source.relativePath == record.item.source.relativePath
                }) else { continue }
                result.items.append(record.item)
            case .updateSource(let id, let expected, let newValue):
                guard let index = legacyMatchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].source = newValue
                result.items[index].availability = .available
            case .updatePath(let id, let expected, let newPath, let newTitle):
                guard let index = legacyMatchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].source.relativePath = newPath
                result.items[index].source.filename = (newPath as NSString).lastPathComponent
                result.items[index].source.sourceTitle = newTitle
            case .updateFinderComment(let id, let expected, let comment):
                guard let index = legacyMatchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].source.finderComment = comment
            case .markMissing(let id, let expected):
                guard let index = legacyMatchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].availability = .temporarilyUnavailable
            case .markAvailable(let id, let expected):
                guard let index = legacyMatchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items[index].availability = .available
            case .markAmbiguous(let id, _):
                if let index = result.items.firstIndex(where: { $0.id == id }) {
                    result.items[index].availability = .ambiguousMatch
                }
            case .removeRecord(let id, let expected):
                guard allowRemovals,
                      let index = legacyMatchingIndex(id: id, expected: expected, in: result) else { continue }
                result.items.remove(at: index)
            }
        }
        return result
    }

    private func legacyMatchingIndex(
        id: UUID,
        expected: SourceRevision,
        in snapshot: CatalogSnapshot
    ) -> Int? {
        snapshot.items.firstIndex {
            $0.id == id &&
                $0.source.relativePath == expected.relativePath &&
                $0.source.portableFingerprint == expected.portableFingerprint &&
                $0.source.fileModificationDate == expected.fileModificationDate
        }
    }
}
