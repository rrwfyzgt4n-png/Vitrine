import Foundation

struct CatalogMarkdownWriter: Sendable {
    func render(_ snapshot: CatalogSnapshot, generator: String = "Vitrine 1.0") throws -> String {
        guard !snapshot.isReadOnly else {
            throw CatalogError.unsupportedSchema(snapshot.schemaVersion)
        }

        let sortedItems = snapshot.items.sorted { lhs, rhs in
            let leftTitle = SearchNormalizer.normalize(lhs.displayTitle)
            let rightTitle = SearchNormalizer.normalize(rhs.displayTitle)
            if leftTitle == rightTitle {
                return lhs.source.relativePath < rhs.source.relativePath
            }
            return leftTitle < rightTitle
        }

        var lines = [
            "---",
            "library-catalog-schema: \(snapshot.schemaVersion)",
            "catalog-id: \(snapshot.catalogID.uuidString)",
            "catalog-name: \(MarkdownEscaping.yamlScalar(snapshot.name))",
            "created-at: \(CatalogDateFormatter.string(from: snapshot.createdAt))",
            "updated-at: \(CatalogDateFormatter.string(from: snapshot.updatedAt))"
        ]

        appendFrontMatter("source-folder-name", snapshot.sourceFolderName, to: &lines)
        appendFrontMatter("source-folder-signature", snapshot.sourceFolderSignature, to: &lines)
        lines.append("record-count: \(sortedItems.count)")
        lines.append("generator: \(MarkdownEscaping.yamlScalar(generator))")

        let knownFrontMatterKeys: Set<String> = [
            "library-catalog-schema", "catalog-id", "catalog-name", "created-at", "updated-at",
            "source-folder-name", "source-folder-signature", "record-count", "generator"
        ]
        for key in snapshot.unknownFrontMatter.keys.sorted() where !knownFrontMatterKeys.contains(key) {
            if let value = snapshot.unknownFrontMatter[key] {
                lines.append("\(key): \(MarkdownEscaping.yamlScalar(value))")
            }
        }
        lines.append("---")

        let unmanagedText = snapshot.unmanagedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if unmanagedText.isEmpty {
            lines.append("# \(MarkdownEscaping.heading(snapshot.name))")
            lines.append("")
            lines.append("\(sortedItems.count) catalogued physical \(sortedItems.count == 1 ? "item" : "items").")
        } else {
            lines.append(unmanagedText)
        }

        for item in sortedItems {
            lines.append("")
            lines.append(contentsOf: render(item))
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    private func render(_ item: CatalogItem) -> [String] {
        var lines = [
            "<!-- library-catalog:item:begin id=\"\(item.id.uuidString)\" -->",
            "## \(MarkdownEscaping.heading(item.displayTitle))"
        ]

        appendField("source-file", item.source.relativePath, to: &lines)
        appendField("source-title", item.source.sourceTitle, to: &lines)
        appendField("portable-fingerprint", item.source.portableFingerprint, to: &lines)
        appendField("full-content-hash", item.source.fullContentHash, to: &lines)
        appendField("file-resource-id", item.source.fileResourceIdentifier, to: &lines)
        appendField("file-size", item.source.fileSize, to: &lines)
        appendField("pixel-width", item.source.pixelWidth, to: &lines)
        appendField("pixel-height", item.source.pixelHeight, to: &lines)
        appendField("file-created", item.source.fileCreationDate, to: &lines)
        appendField("file-modified", item.source.fileModificationDate, to: &lines)
        appendField("availability", item.availability.rawValue, to: &lines)
        appendField("date-added", item.dateAdded, to: &lines)
        appendField("record-modified", item.dateModified, to: &lines)

        let bibliography = item.bibliography
        appendField("isbn-10", bibliography.isbn10, to: &lines)
        appendField("isbn-13", bibliography.isbn13, to: &lines)
        appendField("bibliographic-title", bibliography.title, to: &lines)
        appendField("subtitle", bibliography.subtitle, to: &lines)
        bibliography.authors.forEach { appendField("author", $0, to: &lines) }
        bibliography.translators.forEach { appendField("translator", $0, to: &lines) }
        bibliography.contributors.forEach { contributor in
            appendField("contributor", serialize(contributor), to: &lines)
        }
        appendField("publisher", bibliography.publisher, to: &lines)
        appendField("collection", bibliography.collectionName, to: &lines)
        appendField("collection-number", bibliography.collectionNumber, to: &lines)
        appendField("publication-place", bibliography.publicationPlace, to: &lines)
        appendField("published", bibliography.publicationDate, to: &lines)
        appendField("original-published", bibliography.originalPublicationDate, to: &lines)
        appendField("edition", bibliography.editionDescription, to: &lines)
        appendField("volume", bibliography.volumeDescription, to: &lines)
        appendField("language", bibliography.languageCode, to: &lines)
        bibliography.additionalLanguageCodes.forEach { appendField("additional-language", $0, to: &lines) }
        appendField("original-language", bibliography.originalLanguageCode, to: &lines)
        appendField("pages", bibliography.pageCount, to: &lines)
        appendField("pagination", bibliography.paginationStatus?.rawValue, to: &lines)
        bibliography.physicalAttributes.forEach { appendField("physical-attribute", $0.rawValue, to: &lines) }
        bibliography.subjects.forEach { appendField("subject", $0, to: &lines) }
        appendField("description", bibliography.description, to: &lines)
        appendField("open-library-edition-id", bibliography.openLibraryEditionID, to: &lines)
        appendField("open-library-work-id", bibliography.openLibraryWorkID, to: &lines)
        appendField("metadata-source", bibliography.metadataSource?.rawValue, to: &lines)
        appendField("metadata-retrieved", bibliography.metadataRetrievedAt, to: &lines)
        if bibliography.metadataSource != nil || bibliography.title != nil {
            appendField("metadata-confirmed", bibliography.metadataConfirmedByUser ? "true" : "false", to: &lines)
        }

        lines.append(contentsOf: item.unrecognizedLines)

        if let finderComment = item.source.finderComment, !finderComment.isEmpty {
            lines.append("### Finder notes")
            lines.append(contentsOf: finderComment
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .components(separatedBy: "\n")
                .map { "> \($0)" })
        }
        if !item.personalNotes.isEmpty {
            lines.append("### Personal notes")
            lines.append(item.personalNotes
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n"))
        }
        lines.append(MarkdownTokenizer.itemEnd)
        return lines
    }

    private func appendFrontMatter(_ key: String, _ value: String?, to lines: inout [String]) {
        guard let value, !value.isEmpty else { return }
        lines.append("\(key): \(MarkdownEscaping.yamlScalar(value))")
    }

    private func serialize(_ contributor: BibliographicContributor) -> String {
        "\(contributor.roles.map(\.rawValue).joined(separator: ",")) | \(contributor.name)"
    }

    private func appendField(_ key: String, _ value: String?, to lines: inout [String]) {
        guard let value, !value.isEmpty else { return }
        lines.append("- \(key): `\(MarkdownEscaping.inlineCode(value))`")
    }

    private func appendField<T: BinaryInteger>(_ key: String, _ value: T?, to lines: inout [String]) {
        guard let value else { return }
        appendField(key, String(value), to: &lines)
    }

    private func appendField(_ key: String, _ value: Date?, to lines: inout [String]) {
        guard let value else { return }
        appendField(key, CatalogDateFormatter.string(from: value), to: &lines)
    }
}
