import Foundation

actor CatalogReconciler {
    func diff(catalog: CatalogSnapshot, scan: CatalogScanResult) -> CatalogReconciliationDiff {
        var operations: [CatalogReconciliationOperation] = []
        var unmatchedSources = Dictionary(uniqueKeysWithValues: scan.sources.map { ($0.relativePath, $0) })
        var unmatchedItems: [CatalogItem] = []

        for item in catalog.items {
            let expected = SourceRevision(
                relativePath: item.source.relativePath,
                portableFingerprint: item.source.portableFingerprint,
                fileModificationDate: item.source.fileModificationDate
            )
            if let source = unmatchedSources.removeValue(forKey: item.source.relativePath) {
                operations.append(.updateSource(id: item.id, expected: expected, newValue: source))
            } else {
                unmatchedItems.append(item)
            }
        }

        var sourcesByFingerprint: [String: [SourceFileMetadata]] = [:]
        var sourcesByResourceID: [String: [SourceFileMetadata]] = [:]
        for source in unmatchedSources.values {
            if let fingerprint = source.portableFingerprint {
                sourcesByFingerprint[fingerprint, default: []].append(source)
            }
            if let resourceID = source.fileResourceIdentifier {
                sourcesByResourceID[resourceID, default: []].append(source)
            }
        }

        for item in unmatchedItems {
            let expected = SourceRevision(
                relativePath: item.source.relativePath,
                portableFingerprint: item.source.portableFingerprint,
                fileModificationDate: item.source.fileModificationDate
            )
            if let resourceID = item.source.fileResourceIdentifier,
               let candidates = sourcesByResourceID[resourceID], candidates.count == 1,
               let source = candidates.first {
                operations.append(.updateSource(id: item.id, expected: expected, newValue: source))
                unmatchedSources.removeValue(forKey: source.relativePath)
                if let fingerprint = source.portableFingerprint {
                    sourcesByFingerprint[fingerprint]?.removeAll { $0.relativePath == source.relativePath }
                }
                sourcesByResourceID[resourceID] = []
            } else if let fingerprint = item.source.portableFingerprint,
               let candidates = sourcesByFingerprint[fingerprint],
               candidates.count == 1,
               let source = candidates.first {
                operations.append(.updateSource(id: item.id, expected: expected, newValue: source))
                unmatchedSources.removeValue(forKey: source.relativePath)
                sourcesByFingerprint[fingerprint] = []
            } else if let fingerprint = item.source.portableFingerprint,
                      let candidates = sourcesByFingerprint[fingerprint],
                      candidates.count > 1 {
                let fullMatches = item.source.fullContentHash.map { expectedHash in
                    candidates.filter { $0.fullContentHash == expectedHash }
                } ?? []
                if fullMatches.count == 1, let source = fullMatches.first {
                    operations.append(.updateSource(id: item.id, expected: expected, newValue: source))
                    unmatchedSources.removeValue(forKey: source.relativePath)
                } else {
                    operations.append(.markAmbiguous(
                        id: item.id,
                        candidates: candidates.map { FileCandidate(relativePath: $0.relativePath, portableFingerprint: $0.portableFingerprint) }
                    ))
                    for candidate in candidates {
                        unmatchedSources.removeValue(forKey: candidate.relativePath)
                    }
                }
            } else if scan.completedEnumeration {
                operations.append(.removeRecord(id: item.id, expected: expected))
            } else {
                operations.append(.markMissing(id: item.id, expected: expected))
            }
        }

        for source in unmatchedSources.values {
            operations.append(.addRecord(NewCatalogRecord(item: CatalogItem(source: source))))
        }
        return CatalogReconciliationDiff(
            baseCatalogID: catalog.catalogID,
            baseCatalogUpdatedAt: catalog.updatedAt,
            sourceFolderValidated: false,
            scannedSources: scan.sources,
            operations: operations,
            completedEnumeration: scan.completedEnumeration,
            warnings: scan.warnings.map(\.message)
        )
    }
}
