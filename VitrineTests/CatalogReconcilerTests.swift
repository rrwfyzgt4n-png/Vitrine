import XCTest
@testable import Vitrine

final class CatalogReconcilerTests: XCTestCase {
    func testCompleteScanRemovesConfirmedMissingRecord() async {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Missing.jpg", portableFingerprint: "old"))
        let catalog = CatalogSnapshot(name: "Test", items: [item])
        let scan = CatalogScanResult(sources: [], completedEnumeration: true, warnings: [])

        let diff = await CatalogReconciler().diff(catalog: catalog, scan: scan)

        XCTAssertEqual(diff.operations, [
            .removeRecord(
                id: item.id,
                expected: SourceRevision(relativePath: "Missing.jpg", portableFingerprint: "old", fileModificationDate: nil)
            )
        ])
    }

    func testIncompleteScanNeverRemovesRecord() async {
        let item = CatalogItem(source: SourceFileMetadata(relativePath: "Missing.jpg", portableFingerprint: "old"))
        let catalog = CatalogSnapshot(name: "Test", items: [item])
        let scan = CatalogScanResult(
            sources: [],
            completedEnumeration: false,
            warnings: [CatalogScanWarning(relativePath: "Changing.jpg", message: "Retry later")]
        )

        let diff = await CatalogReconciler().diff(catalog: catalog, scan: scan)

        XCTAssertEqual(diff.operations.first, .markMissing(
            id: item.id,
            expected: SourceRevision(relativePath: "Missing.jpg", portableFingerprint: "old", fileModificationDate: nil)
        ))
        XCTAssertFalse(diff.operations.contains { if case .removeRecord = $0 { true } else { false } })
    }

    func testFingerprintRenameRetainsRecordIdentityAndMetadata() async {
        let id = UUID()
        let item = CatalogItem(
            id: id,
            source: SourceFileMetadata(relativePath: "Old.jpg", portableFingerprint: "same"),
            bibliography: BibliographicMetadata(title: "Confirmed", metadataConfirmedByUser: true)
        )
        let moved = SourceFileMetadata(relativePath: "Nested/New.jpg", portableFingerprint: "same")

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Test", items: [item]),
            scan: CatalogScanResult(sources: [moved], completedEnumeration: true, warnings: [])
        )

        XCTAssertEqual(diff.operations, [
            .updateSource(
                id: id,
                expected: SourceRevision(relativePath: "Old.jpg", portableFingerprint: "same", fileModificationDate: nil),
                newValue: moved
            )
        ])
    }

    func testUnstableKnownPathIsDeferredWithoutChangingAvailability() async {
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Changing.jpg", portableFingerprint: "old")
        )
        let scan = CatalogScanResult(
            sources: [],
            completedEnumeration: false,
            warnings: [CatalogScanWarning(relativePath: "Changing.jpg", message: "Retry later")]
        )

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Test", items: [item]),
            scan: scan
        )

        XCTAssertTrue(diff.operations.isEmpty)
    }

    func testOneScannedSourceCannotBeAssignedToTwoRecords() async {
        let first = CatalogItem(
            source: SourceFileMetadata(relativePath: "First.jpg", fileResourceIdentifier: "resource")
        )
        let second = CatalogItem(
            source: SourceFileMetadata(relativePath: "Second.jpg", fileResourceIdentifier: "resource")
        )
        let moved = SourceFileMetadata(relativePath: "Moved.jpg", fileResourceIdentifier: "resource")

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Test", items: [first, second]),
            scan: CatalogScanResult(sources: [moved], completedEnumeration: true, warnings: [])
        )

        XCTAssertEqual(diff.operations.filter { if case .updateSource = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(diff.operations.filter { if case .removeRecord = $0 { true } else { false } }.count, 1)
    }

    func testMetadataOnlyRecordSurvivesCompleteRefreshWhenCoverRemainsAbsent() async {
        let item = CatalogItem(
            source: SourceFileMetadata(relativePath: "Absent.jpg", portableFingerprint: "fingerprint"),
            availability: .metadataOnly
        )

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Library", items: [item]),
            scan: CatalogScanResult(sources: [], completedEnumeration: true, warnings: [])
        )

        XCTAssertTrue(diff.operations.isEmpty)
    }

    func testMetadataOnlyRecordBecomesAvailableWhenItsSourceReappears() async {
        let source = SourceFileMetadata(relativePath: "Returned.jpg", portableFingerprint: "fingerprint")
        let item = CatalogItem(source: source, availability: .metadataOnly)
        let catalog = CatalogSnapshot(name: "Library", items: [item])

        let diff = await CatalogReconciler().diff(
            catalog: catalog,
            scan: CatalogScanResult(sources: [source], completedEnumeration: true, warnings: [])
        )
        let refreshed = await MainActor.run {
            CatalogStore().apply(diff: diff, to: catalog, allowRemovals: true)
        }

        XCTAssertEqual(refreshed.items.first?.availability, .available)
    }

    func testThreeUnresolvedItemsAndSourcesBecomeOneAmbiguousCluster() async {
        let items = (1...3).map {
            CatalogItem(source: SourceFileMetadata(relativePath: "Old\($0).jpg", portableFingerprint: "shared"))
        }
        let sources = ["NewC.jpg", "NewA.jpg", "NewB.jpg"].map {
            SourceFileMetadata(relativePath: $0, portableFingerprint: "shared")
        }

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Library", items: items),
            scan: CatalogScanResult(sources: sources, completedEnumeration: true, warnings: [])
        )

        let ambiguities = diff.operations.compactMap { operation -> (UUID, [FileCandidate])? in
            guard case .markAmbiguous(let id, let candidates) = operation else { return nil }
            return (id, candidates)
        }
        XCTAssertEqual(ambiguities.map(\.0), items.map(\.id))
        XCTAssertTrue(ambiguities.allSatisfy { $0.1.map(\.relativePath) == ["NewA.jpg", "NewB.jpg", "NewC.jpg"] })
        XCTAssertFalse(diff.operations.contains { if case .removeRecord = $0 { true } else { false } })
        XCTAssertFalse(diff.operations.contains { if case .addRecord = $0 { true } else { false } })
    }

    func testDistinctFullHashesResolveEveryMemberOfFingerprintCluster() async {
        let items = ["hash-c", "hash-a", "hash-b"].enumerated().map { index, hash in
            CatalogItem(source: SourceFileMetadata(
                relativePath: "Old\(index).jpg",
                portableFingerprint: "shared",
                fullContentHash: hash
            ))
        }
        let sources = [
            SourceFileMetadata(relativePath: "NewB.jpg", portableFingerprint: "shared", fullContentHash: "hash-b"),
            SourceFileMetadata(relativePath: "NewC.jpg", portableFingerprint: "shared", fullContentHash: "hash-c"),
            SourceFileMetadata(relativePath: "NewA.jpg", portableFingerprint: "shared", fullContentHash: "hash-a"),
        ]

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Library", items: items),
            scan: CatalogScanResult(sources: sources, completedEnumeration: true, warnings: [])
        )

        let updates = diff.operations.compactMap { operation -> (UUID, String)? in
            guard case .updateSource(let id, _, let source) = operation else { return nil }
            return (id, source.relativePath)
        }
        XCTAssertEqual(updates.map(\.0), items.map(\.id))
        XCTAssertEqual(updates.map(\.1), ["NewC.jpg", "NewA.jpg", "NewB.jpg"])
        XCTAssertEqual(diff.operations.count, 3)
    }

    func testMoreItemsThanSourcesMarksEveryItemAmbiguousWithoutRemoval() async {
        let items = (1...3).map {
            CatalogItem(source: SourceFileMetadata(relativePath: "Old\($0).jpg", portableFingerprint: "shared"))
        }
        let sources = (1...2).map {
            SourceFileMetadata(relativePath: "New\($0).jpg", portableFingerprint: "shared")
        }

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Library", items: items),
            scan: CatalogScanResult(sources: sources, completedEnumeration: true, warnings: [])
        )

        XCTAssertEqual(diff.operations.filter { if case .markAmbiguous = $0 { true } else { false } }.count, 3)
        XCTAssertFalse(diff.operations.contains { if case .removeRecord = $0 { true } else { false } })
    }

    func testMoreSourcesThanItemsDefersEveryCandidateUntilReview() async {
        let items = (1...2).map {
            CatalogItem(source: SourceFileMetadata(relativePath: "Old\($0).jpg", portableFingerprint: "shared"))
        }
        let sources = (1...3).map {
            SourceFileMetadata(relativePath: "New\($0).jpg", portableFingerprint: "shared")
        }

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Library", items: items),
            scan: CatalogScanResult(sources: sources, completedEnumeration: true, warnings: [])
        )

        XCTAssertEqual(diff.operations.filter { if case .markAmbiguous = $0 { true } else { false } }.count, 2)
        XCTAssertFalse(diff.operations.contains { if case .addRecord = $0 { true } else { false } })
    }

    func testFingerprintClusterOperationsAreStableAcrossSourceOrderings() async {
        let items = (1...3).map {
            CatalogItem(source: SourceFileMetadata(relativePath: "Old\($0).jpg", portableFingerprint: "shared"))
        }
        let sources = ["Z.jpg", "A.jpg", "M.jpg"].map {
            SourceFileMetadata(relativePath: $0, portableFingerprint: "shared")
        }
        let catalog = CatalogSnapshot(name: "Library", items: items)

        let forward = await CatalogReconciler().diff(
            catalog: catalog,
            scan: CatalogScanResult(sources: sources, completedEnumeration: true, warnings: [])
        )
        let reverse = await CatalogReconciler().diff(
            catalog: catalog,
            scan: CatalogScanResult(sources: sources.reversed(), completedEnumeration: true, warnings: [])
        )

        XCTAssertEqual(forward.operations, reverse.operations)
    }

    func testAmbiguousClusterDoesNotConsumeUnrelatedRecordsOrSources() async {
        let ambiguousItems = (1...2).map {
            CatalogItem(source: SourceFileMetadata(relativePath: "Old\($0).jpg", portableFingerprint: "shared"))
        }
        let missing = CatalogItem(
            source: SourceFileMetadata(relativePath: "Missing.jpg", portableFingerprint: "missing")
        )
        let ambiguousSources = (1...2).map {
            SourceFileMetadata(relativePath: "Moved\($0).jpg", portableFingerprint: "shared")
        }
        let newSource = SourceFileMetadata(relativePath: "New.jpg", portableFingerprint: "new")

        let diff = await CatalogReconciler().diff(
            catalog: CatalogSnapshot(name: "Library", items: ambiguousItems + [missing]),
            scan: CatalogScanResult(
                sources: ambiguousSources + [newSource],
                completedEnumeration: true,
                warnings: []
            )
        )

        XCTAssertEqual(diff.operations.filter { if case .markAmbiguous = $0 { true } else { false } }.count, 2)
        XCTAssertEqual(diff.operations.filter { if case .removeRecord = $0 { true } else { false } }.count, 1)
        XCTAssertEqual(diff.operations.filter { if case .addRecord = $0 { true } else { false } }.count, 1)
    }

    func testMetadataOnlyAndTemporaryAvailabilityLabelsAreDistinct() {
        XCTAssertNotEqual(ItemAvailability.metadataOnly.inspectorLabel, ItemAvailability.temporarilyUnavailable.inspectorLabel)
        XCTAssertEqual(ItemAvailability.metadataOnly.inspectorLabel, L10n.text("Kept without cover"))
    }
}
