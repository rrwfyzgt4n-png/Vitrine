import Foundation

actor CatalogReconciler {
    func diff(catalog: CatalogSnapshot, scan: CatalogScanResult) -> CatalogReconciliationDiff {
        var operations: [CatalogReconciliationOperation] = []
        var unmatchedSources = Dictionary(uniqueKeysWithValues: scan.sources.map { ($0.relativePath, $0) })
        var unmatchedItems: [CatalogItem] = []

        for item in catalog.items {
            let expected = revision(for: item)
            if let source = unmatchedSources.removeValue(forKey: item.source.relativePath) {
                operations.append(.updateSource(id: item.id, expected: expected, newValue: source))
            } else {
                unmatchedItems.append(item)
            }
        }

        var sourcesByResourceID: [String: [SourceFileMetadata]] = [:]
        for source in unmatchedSources.values.sorted(by: sourcePathOrder) {
            if let resourceID = source.fileResourceIdentifier {
                sourcesByResourceID[resourceID, default: []].append(source)
            }
        }

        var fingerprintItems: [CatalogItem] = []
        for item in unmatchedItems {
            if let resourceID = item.source.fileResourceIdentifier,
               let candidates = sourcesByResourceID[resourceID]?.filter({ unmatchedSources[$0.relativePath] != nil }),
               candidates.count == 1,
               let source = candidates.first {
                operations.append(.updateSource(id: item.id, expected: revision(for: item), newValue: source))
                unmatchedSources.removeValue(forKey: source.relativePath)
            } else {
                fingerprintItems.append(item)
            }
        }

        var itemsByFingerprint: [String: [CatalogItem]] = [:]
        for item in fingerprintItems {
            if let fingerprint = item.source.portableFingerprint {
                itemsByFingerprint[fingerprint, default: []].append(item)
            }
        }

        var handledItemIDs: Set<UUID> = []
        for fingerprint in itemsByFingerprint.keys.sorted() {
            let items = itemsByFingerprint[fingerprint] ?? []
            var sources = unmatchedSources.values
                .filter { $0.portableFingerprint == fingerprint }
                .sorted(by: sourcePathOrder)
            guard !sources.isEmpty else { continue }

            var remainingItems = items
            let itemHashCounts = Dictionary(grouping: remainingItems.compactMap { item in
                item.source.fullContentHash.map { ($0, item) }
            }, by: { $0.0 })
            let sourceHashCounts = Dictionary(grouping: sources.compactMap { source in
                source.fullContentHash.map { ($0, source) }
            }, by: { $0.0 })
            var fullHashMatches: [(CatalogItem, SourceFileMetadata)] = []
            for item in remainingItems {
                guard let hash = item.source.fullContentHash,
                      itemHashCounts[hash]?.count == 1,
                      sourceHashCounts[hash]?.count == 1,
                      let source = sourceHashCounts[hash]?.first?.1 else { continue }
                fullHashMatches.append((item, source))
            }
            for (item, source) in fullHashMatches {
                operations.append(.updateSource(id: item.id, expected: revision(for: item), newValue: source))
                handledItemIDs.insert(item.id)
                unmatchedSources.removeValue(forKey: source.relativePath)
            }
            let matchedItemIDs = Set(fullHashMatches.map { $0.0.id })
            let matchedSourcePaths = Set(fullHashMatches.map { $0.1.relativePath })
            remainingItems.removeAll { matchedItemIDs.contains($0.id) }
            sources.removeAll { matchedSourcePaths.contains($0.relativePath) }

            if remainingItems.count == 1,
               sources.count == 1,
               let item = remainingItems.first,
               let source = sources.first,
               fullHashesAreCompatible(item: item, source: source) {
                operations.append(.updateSource(id: item.id, expected: revision(for: item), newValue: source))
                handledItemIDs.insert(item.id)
                unmatchedSources.removeValue(forKey: source.relativePath)
                continue
            }

            var consumedSourcePaths: Set<String> = []
            for item in remainingItems {
                let candidates = compatibleSources(for: item, in: sources)
                guard !candidates.isEmpty else { continue }
                operations.append(.markAmbiguous(
                    id: item.id,
                    candidates: candidates.map {
                        FileCandidate(relativePath: $0.relativePath, portableFingerprint: $0.portableFingerprint)
                    }
                ))
                handledItemIDs.insert(item.id)
                consumedSourcePaths.formUnion(candidates.map(\.relativePath))
            }
            for path in consumedSourcePaths {
                unmatchedSources.removeValue(forKey: path)
            }
        }

        for item in fingerprintItems where !handledItemIDs.contains(item.id) {
            if scan.warnings.contains(where: { $0.relativePath == item.source.relativePath }) {
                continue
            }
            if item.availability == .metadataOnly {
                continue
            }
            let expected = revision(for: item)
            if scan.completedEnumeration {
                operations.append(.removeRecord(id: item.id, expected: expected))
            } else {
                operations.append(.markMissing(id: item.id, expected: expected))
            }
        }

        for source in unmatchedSources.values.sorted(by: sourcePathOrder) {
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

    private func revision(for item: CatalogItem) -> SourceRevision {
        SourceRevision(
            relativePath: item.source.relativePath,
            portableFingerprint: item.source.portableFingerprint,
            fileModificationDate: item.source.fileModificationDate
        )
    }

    private func compatibleSources(
        for item: CatalogItem,
        in sources: [SourceFileMetadata]
    ) -> [SourceFileMetadata] {
        sources.filter { fullHashesAreCompatible(item: item, source: $0) }
    }

    private func fullHashesAreCompatible(
        item: CatalogItem,
        source: SourceFileMetadata
    ) -> Bool {
        guard let itemHash = item.source.fullContentHash,
              let sourceHash = source.fullContentHash else { return true }
        return itemHash == sourceHash
    }

    private func sourcePathOrder(_ lhs: SourceFileMetadata, _ rhs: SourceFileMetadata) -> Bool {
        lhs.relativePath < rhs.relativePath
    }
}
