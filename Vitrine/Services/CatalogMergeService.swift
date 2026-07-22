import Foundation

actor CatalogMergeService {
    private let valueFormatter = CatalogMergeValueFormatter()
    func merge(base: CatalogSnapshot, local: CatalogSnapshot, external: CatalogSnapshot) -> PendingCatalogMerge {
        var conflicts: [CatalogMergeConflict] = []
        var merged = local
        merged.name = choose(
            base: base.name, local: local.name, external: external.name,
            field: .catalogName, conflicts: &conflicts
        )
        merged.sourceFolderName = choose(
            base: base.sourceFolderName, local: local.sourceFolderName, external: external.sourceFolderName,
            field: .sourceFolderName, conflicts: &conflicts
        )
        merged.sourceFolderSignature = choose(
            base: base.sourceFolderSignature, local: local.sourceFolderSignature, external: external.sourceFolderSignature,
            field: .sourceFolderSignature, conflicts: &conflicts
        )
        merged.unknownFrontMatter = local.unknownFrontMatter.merging(external.unknownFrontMatter) { local, external in
            local == external ? local : local
        }
        merged.unmanagedText = choose(
            base: base.unmanagedText, local: local.unmanagedText, external: external.unmanagedText,
            field: .unrecognizedLines, conflicts: &conflicts
        )
        merged.updatedAt = max(local.updatedAt, external.updatedAt)

        let baseItems = Dictionary(uniqueKeysWithValues: base.items.map { ($0.id, $0) })
        let localItems = Dictionary(uniqueKeysWithValues: local.items.map { ($0.id, $0) })
        let externalItems = Dictionary(uniqueKeysWithValues: external.items.map { ($0.id, $0) })
        let ids = Set(baseItems.keys).union(localItems.keys).union(externalItems.keys)
        merged.items = ids.compactMap { id in
            mergeItem(
                id: id,
                base: baseItems[id],
                local: localItems[id],
                external: externalItems[id],
                conflicts: &conflicts
            )
        }
        return PendingCatalogMerge(merged: merged, external: external, conflicts: conflicts)
    }

    func resolving(_ pending: PendingCatalogMerge, useExternal conflictIDs: Set<UUID>) -> CatalogSnapshot {
        var result = pending.merged
        for conflict in pending.conflicts where conflictIDs.contains(conflict.id) {
            applyExternal(conflict, from: pending.external, to: &result)
        }
        result.updatedAt = .now
        return result
    }

    private func mergeItem(
        id: UUID,
        base: CatalogItem?,
        local: CatalogItem?,
        external: CatalogItem?,
        conflicts: inout [CatalogMergeConflict]
    ) -> CatalogItem? {
        switch (base, local, external) {
        case (nil, let local?, nil): return local
        case (nil, nil, let external?): return external
        case (nil, let local?, let external?):
            if local == external { return local }
            addConflict(recordID: id, title: local.displayTitle, field: .record, local: local, external: external, to: &conflicts)
            return local
        case (let base?, nil, let external?):
            if external == base { return nil }
            addConflict(recordID: id, title: external.displayTitle, field: .record, local: L10n.text("Removed"), external: external, to: &conflicts)
            return nil
        case (let base?, let local?, nil):
            if local == base { return nil }
            addConflict(recordID: id, title: local.displayTitle, field: .record, local: local, external: L10n.text("Removed"), to: &conflicts)
            return local
        case (_, nil, nil): return nil
        case (let base?, let local?, let external?):
            var item = local
            let title = local.displayTitle
            item.source = choose(base: base.source, local: local.source, external: external.source, recordID: id, title: title, field: .source, conflicts: &conflicts)
            item.bibliography.isbn10 = choose(base: base.bibliography.isbn10, local: local.bibliography.isbn10, external: external.bibliography.isbn10, recordID: id, title: title, field: .isbn10, conflicts: &conflicts)
            item.bibliography.isbn13 = choose(base: base.bibliography.isbn13, local: local.bibliography.isbn13, external: external.bibliography.isbn13, recordID: id, title: title, field: .isbn13, conflicts: &conflicts)
            item.bibliography.title = choose(base: base.bibliography.title, local: local.bibliography.title, external: external.bibliography.title, recordID: id, title: title, field: .title, conflicts: &conflicts)
            item.bibliography.subtitle = choose(base: base.bibliography.subtitle, local: local.bibliography.subtitle, external: external.bibliography.subtitle, recordID: id, title: title, field: .subtitle, conflicts: &conflicts)
            item.bibliography.authors = choose(base: base.bibliography.authors, local: local.bibliography.authors, external: external.bibliography.authors, recordID: id, title: title, field: .authors, conflicts: &conflicts)
            item.bibliography.translators = choose(base: base.bibliography.translators, local: local.bibliography.translators, external: external.bibliography.translators, recordID: id, title: title, field: .translators, conflicts: &conflicts)
            item.bibliography.contributors = choose(base: base.bibliography.contributors, local: local.bibliography.contributors, external: external.bibliography.contributors, recordID: id, title: title, field: .contributors, conflicts: &conflicts)
            item.bibliography.publisher = choose(base: base.bibliography.publisher, local: local.bibliography.publisher, external: external.bibliography.publisher, recordID: id, title: title, field: .publisher, conflicts: &conflicts)
            item.bibliography.collectionName = choose(base: base.bibliography.collectionName, local: local.bibliography.collectionName, external: external.bibliography.collectionName, recordID: id, title: title, field: .collectionName, conflicts: &conflicts)
            item.bibliography.collectionNumber = choose(base: base.bibliography.collectionNumber, local: local.bibliography.collectionNumber, external: external.bibliography.collectionNumber, recordID: id, title: title, field: .collectionNumber, conflicts: &conflicts)
            item.bibliography.publicationPlace = choose(base: base.bibliography.publicationPlace, local: local.bibliography.publicationPlace, external: external.bibliography.publicationPlace, recordID: id, title: title, field: .publicationPlace, conflicts: &conflicts)
            item.bibliography.publicationDate = choose(base: base.bibliography.publicationDate, local: local.bibliography.publicationDate, external: external.bibliography.publicationDate, recordID: id, title: title, field: .publicationDate, conflicts: &conflicts)
            item.bibliography.originalPublicationDate = choose(base: base.bibliography.originalPublicationDate, local: local.bibliography.originalPublicationDate, external: external.bibliography.originalPublicationDate, recordID: id, title: title, field: .originalPublicationDate, conflicts: &conflicts)
            item.bibliography.editionDescription = choose(base: base.bibliography.editionDescription, local: local.bibliography.editionDescription, external: external.bibliography.editionDescription, recordID: id, title: title, field: .editionDescription, conflicts: &conflicts)
            item.bibliography.volumeDescription = choose(base: base.bibliography.volumeDescription, local: local.bibliography.volumeDescription, external: external.bibliography.volumeDescription, recordID: id, title: title, field: .volumeDescription, conflicts: &conflicts)
            item.bibliography.languageCode = choose(base: base.bibliography.languageCode, local: local.bibliography.languageCode, external: external.bibliography.languageCode, recordID: id, title: title, field: .languageCode, conflicts: &conflicts)
            item.bibliography.additionalLanguageCodes = choose(base: base.bibliography.additionalLanguageCodes, local: local.bibliography.additionalLanguageCodes, external: external.bibliography.additionalLanguageCodes, recordID: id, title: title, field: .additionalLanguageCodes, conflicts: &conflicts)
            item.bibliography.originalLanguageCode = choose(base: base.bibliography.originalLanguageCode, local: local.bibliography.originalLanguageCode, external: external.bibliography.originalLanguageCode, recordID: id, title: title, field: .originalLanguageCode, conflicts: &conflicts)
            item.bibliography.pageCount = choose(base: base.bibliography.pageCount, local: local.bibliography.pageCount, external: external.bibliography.pageCount, recordID: id, title: title, field: .pageCount, conflicts: &conflicts)
            item.bibliography.paginationStatus = choose(base: base.bibliography.paginationStatus, local: local.bibliography.paginationStatus, external: external.bibliography.paginationStatus, recordID: id, title: title, field: .paginationStatus, conflicts: &conflicts)
            item.bibliography.physicalAttributes = choose(base: base.bibliography.physicalAttributes, local: local.bibliography.physicalAttributes, external: external.bibliography.physicalAttributes, recordID: id, title: title, field: .physicalAttributes, conflicts: &conflicts)
            item.bibliography.subjects = choose(base: base.bibliography.subjects, local: local.bibliography.subjects, external: external.bibliography.subjects, recordID: id, title: title, field: .subjects, conflicts: &conflicts)
            item.bibliography.description = choose(base: base.bibliography.description, local: local.bibliography.description, external: external.bibliography.description, recordID: id, title: title, field: .description, conflicts: &conflicts)
            item.bibliography.openLibraryEditionID = choose(base: base.bibliography.openLibraryEditionID, local: local.bibliography.openLibraryEditionID, external: external.bibliography.openLibraryEditionID, recordID: id, title: title, field: .openLibraryEditionID, conflicts: &conflicts)
            item.bibliography.openLibraryWorkID = choose(base: base.bibliography.openLibraryWorkID, local: local.bibliography.openLibraryWorkID, external: external.bibliography.openLibraryWorkID, recordID: id, title: title, field: .openLibraryWorkID, conflicts: &conflicts)
            item.bibliography.metadataSource = choose(base: base.bibliography.metadataSource, local: local.bibliography.metadataSource, external: external.bibliography.metadataSource, recordID: id, title: title, field: .metadataSource, conflicts: &conflicts)
            item.bibliography.metadataRetrievedAt = choose(base: base.bibliography.metadataRetrievedAt, local: local.bibliography.metadataRetrievedAt, external: external.bibliography.metadataRetrievedAt, recordID: id, title: title, field: .metadataRetrievedAt, conflicts: &conflicts)
            item.bibliography.metadataConfirmedByUser = choose(base: base.bibliography.metadataConfirmedByUser, local: local.bibliography.metadataConfirmedByUser, external: external.bibliography.metadataConfirmedByUser, recordID: id, title: title, field: .metadataConfirmedByUser, conflicts: &conflicts)
            item.personalNotes = choose(base: base.personalNotes, local: local.personalNotes, external: external.personalNotes, recordID: id, title: title, field: .personalNotes, conflicts: &conflicts)
            item.availability = choose(base: base.availability, local: local.availability, external: external.availability, recordID: id, title: title, field: .availability, conflicts: &conflicts)
            item.unrecognizedLines = choose(base: base.unrecognizedLines, local: local.unrecognizedLines, external: external.unrecognizedLines, recordID: id, title: title, field: .unrecognizedLines, conflicts: &conflicts)
            item.dateModified = max(local.dateModified, external.dateModified)
            return item
        }
    }

    private func choose<Value: Equatable>(
        base: Value,
        local: Value,
        external: Value,
        recordID: UUID? = nil,
        title: String? = nil,
        field: CatalogMergeField,
        conflicts: inout [CatalogMergeConflict]
    ) -> Value {
        if local == external { return local }
        if local == base { return external }
        if external == base { return local }
        addConflict(recordID: recordID, title: title, field: field, local: local, external: external, to: &conflicts)
        return local
    }

    private func addConflict<Local, External>(
        recordID: UUID?, title: String?, field: CatalogMergeField,
        local: Local, external: External, to conflicts: inout [CatalogMergeConflict]
    ) {
        conflicts.append(CatalogMergeConflict(
            recordID: recordID,
            bookTitle: title,
            field: field,
            localValue: valueFormatter.string(for: local),
            externalValue: valueFormatter.string(for: external)
        ))
    }

    private func applyExternal(_ conflict: CatalogMergeConflict, from external: CatalogSnapshot, to result: inout CatalogSnapshot) {
        if conflict.recordID == nil {
            switch conflict.field {
            case .catalogName: result.name = external.name
            case .sourceFolderName: result.sourceFolderName = external.sourceFolderName
            case .sourceFolderSignature: result.sourceFolderSignature = external.sourceFolderSignature
            case .unrecognizedLines: result.unmanagedText = external.unmanagedText
            default: break
            }
            return
        }
        guard let id = conflict.recordID else { return }
        if conflict.field == .record {
            if let externalItem = external.items.first(where: { $0.id == id }) {
                if let index = result.items.firstIndex(where: { $0.id == id }) { result.items[index] = externalItem }
                else { result.items.append(externalItem) }
            } else {
                result.items.removeAll { $0.id == id }
            }
            return
        }
        guard let externalItem = external.items.first(where: { $0.id == id }),
              let index = result.items.firstIndex(where: { $0.id == id }) else { return }
        switch conflict.field {
        case .source: result.items[index].source = externalItem.source
        case .isbn10: result.items[index].bibliography.isbn10 = externalItem.bibliography.isbn10
        case .isbn13: result.items[index].bibliography.isbn13 = externalItem.bibliography.isbn13
        case .title: result.items[index].bibliography.title = externalItem.bibliography.title
        case .subtitle: result.items[index].bibliography.subtitle = externalItem.bibliography.subtitle
        case .authors: result.items[index].bibliography.authors = externalItem.bibliography.authors
        case .translators: result.items[index].bibliography.translators = externalItem.bibliography.translators
        case .contributors: result.items[index].bibliography.contributors = externalItem.bibliography.contributors
        case .publisher: result.items[index].bibliography.publisher = externalItem.bibliography.publisher
        case .collectionName: result.items[index].bibliography.collectionName = externalItem.bibliography.collectionName
        case .collectionNumber: result.items[index].bibliography.collectionNumber = externalItem.bibliography.collectionNumber
        case .publicationPlace: result.items[index].bibliography.publicationPlace = externalItem.bibliography.publicationPlace
        case .publicationDate: result.items[index].bibliography.publicationDate = externalItem.bibliography.publicationDate
        case .originalPublicationDate: result.items[index].bibliography.originalPublicationDate = externalItem.bibliography.originalPublicationDate
        case .editionDescription: result.items[index].bibliography.editionDescription = externalItem.bibliography.editionDescription
        case .volumeDescription: result.items[index].bibliography.volumeDescription = externalItem.bibliography.volumeDescription
        case .languageCode: result.items[index].bibliography.languageCode = externalItem.bibliography.languageCode
        case .additionalLanguageCodes: result.items[index].bibliography.additionalLanguageCodes = externalItem.bibliography.additionalLanguageCodes
        case .originalLanguageCode: result.items[index].bibliography.originalLanguageCode = externalItem.bibliography.originalLanguageCode
        case .pageCount: result.items[index].bibliography.pageCount = externalItem.bibliography.pageCount
        case .paginationStatus: result.items[index].bibliography.paginationStatus = externalItem.bibliography.paginationStatus
        case .physicalAttributes: result.items[index].bibliography.physicalAttributes = externalItem.bibliography.physicalAttributes
        case .subjects: result.items[index].bibliography.subjects = externalItem.bibliography.subjects
        case .description: result.items[index].bibliography.description = externalItem.bibliography.description
        case .openLibraryEditionID: result.items[index].bibliography.openLibraryEditionID = externalItem.bibliography.openLibraryEditionID
        case .openLibraryWorkID: result.items[index].bibliography.openLibraryWorkID = externalItem.bibliography.openLibraryWorkID
        case .metadataSource: result.items[index].bibliography.metadataSource = externalItem.bibliography.metadataSource
        case .metadataRetrievedAt: result.items[index].bibliography.metadataRetrievedAt = externalItem.bibliography.metadataRetrievedAt
        case .metadataConfirmedByUser: result.items[index].bibliography.metadataConfirmedByUser = externalItem.bibliography.metadataConfirmedByUser
        case .personalNotes: result.items[index].personalNotes = externalItem.personalNotes
        case .availability: result.items[index].availability = externalItem.availability
        case .unrecognizedLines: result.items[index].unrecognizedLines = externalItem.unrecognizedLines
        case .catalogName, .sourceFolderName, .sourceFolderSignature, .record: break
        }
    }
}
