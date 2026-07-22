import Foundation

struct CatalogMarkdownParser: Sendable {
    func parse(_ source: String) throws -> CatalogParseResult {
        let lines = MarkdownTokenizer.normalizedLines(in: source)
        var diagnostics: [MarkdownDiagnostic] = []
        guard lines.first == "---", let frontMatterEnd = lines.dropFirst().firstIndex(of: "---") else {
            throw CatalogError.catalogMalformed
        }

        let frontMatter = parseFrontMatter(Array(lines[1..<frontMatterEnd]), diagnostics: &diagnostics)
        guard let schemaValue = frontMatter["library-catalog-schema"], let schemaVersion = Int(schemaValue) else {
            throw CatalogError.catalogMalformed
        }
        guard let catalogIDValue = frontMatter["catalog-id"], let catalogID = UUID(uuidString: catalogIDValue) else {
            throw CatalogError.catalogMalformed
        }

        let name = frontMatter["catalog-name"] ?? "Untitled Catalog"
        let createdAt = parseDate(frontMatter["created-at"], key: "created-at", diagnostics: &diagnostics) ?? .distantPast
        let updatedAt = parseDate(frontMatter["updated-at"], key: "updated-at", diagnostics: &diagnostics) ?? createdAt
        let readOnly = schemaVersion > CatalogSnapshot.supportedSchemaVersion
        if readOnly {
            diagnostics.append(.init(
                severity: .warning,
                code: .unsupportedSchema,
                message: "The catalog schema is newer than this application supports."
            ))
        }

        var unknownFrontMatter = frontMatter
        for key in [
            "library-catalog-schema", "catalog-id", "catalog-name", "created-at", "updated-at",
            "source-folder-name", "source-folder-signature", "record-count", "generator"
        ] {
            unknownFrontMatter.removeValue(forKey: key)
        }

        var items: [CatalogItem] = []
        var seenIDs: Set<UUID> = []
        var unmanagedLines: [String] = []
        var activeRecord: (id: UUID, startLine: Int, lines: [String])?

        for index in lines.index(after: frontMatterEnd)..<lines.endIndex {
            let line = lines[index]
            let lineNumber = index + 1

            if line.hasPrefix(MarkdownTokenizer.itemBeginPrefix) {
                guard activeRecord == nil else {
                    diagnostics.append(.init(severity: .error, code: .overlappingRecord, line: lineNumber, message: "A record begins before the previous record ends."))
                    continue
                }
                guard let id = MarkdownTokenizer.recordID(from: line) else {
                    diagnostics.append(.init(severity: .error, code: .invalidRecordID, line: lineNumber, message: "A record has an invalid identifier."))
                    continue
                }
                activeRecord = (id, lineNumber, [])
            } else if line == MarkdownTokenizer.itemEnd {
                guard let record = activeRecord else {
                    diagnostics.append(.init(severity: .error, code: .invalidRecordMarker, line: lineNumber, message: "A record end marker has no matching start marker."))
                    continue
                }
                activeRecord = nil
                if seenIDs.contains(record.id) {
                    diagnostics.append(.init(severity: .error, code: .duplicateRecordID, line: record.startLine, recordID: record.id, message: "A duplicate record was ignored."))
                    continue
                }
                do {
                    let item = try parseRecord(id: record.id, lines: record.lines, startLine: record.startLine, diagnostics: &diagnostics)
                    seenIDs.insert(record.id)
                    items.append(item)
                } catch {
                    diagnostics.append(.init(severity: .error, code: .missingRequiredField, line: record.startLine, recordID: record.id, message: "A record is missing required source information and was ignored."))
                }
            } else if activeRecord != nil {
                activeRecord?.lines.append(line)
            } else {
                unmanagedLines.append(line)
            }
        }

        if let activeRecord {
            diagnostics.append(.init(severity: .error, code: .unclosedRecord, line: activeRecord.startLine, recordID: activeRecord.id, message: "An unfinished record was ignored."))
        }

        if let expectedCount = frontMatter["record-count"].flatMap(Int.init), expectedCount != items.count {
            diagnostics.append(.init(severity: .warning, code: .recordCountMismatch, message: "The catalog item count did not match the records that could be read."))
        }

        let snapshot = CatalogSnapshot(
            schemaVersion: schemaVersion,
            catalogID: catalogID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sourceFolderName: frontMatter["source-folder-name"],
            sourceFolderSignature: frontMatter["source-folder-signature"],
            items: items,
            unknownFrontMatter: unknownFrontMatter,
            unmanagedText: unmanagedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            isReadOnly: readOnly
        )
        return CatalogParseResult(snapshot: snapshot, diagnostics: diagnostics)
    }

    private func parseFrontMatter(_ lines: [String], diagnostics: inout [MarkdownDiagnostic]) -> [String: String] {
        var result: [String: String] = [:]
        for (offset, line) in lines.enumerated() {
            guard let separator = line.firstIndex(of: ":") else {
                diagnostics.append(.init(severity: .warning, code: .invalidFrontMatter, line: offset + 2, message: "An unrecognized front-matter line was ignored."))
                continue
            }
            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            result[key] = MarkdownEscaping.unescapeYAMLScalar(value)
        }
        return result
    }

    private func parseRecord(
        id: UUID,
        lines: [String],
        startLine: Int,
        diagnostics: inout [MarkdownDiagnostic]
    ) throws -> CatalogItem {
        var fields: [String: [String]] = [:]
        var unrecognizedLines: [String] = []
        var finderNoteLines: [String] = []
        var personalNoteLines: [String] = []
        enum Section { case fields, finderNotes, personalNotes }
        var section = Section.fields

        let sourceKeys: Set<String> = [
            "source-file", "source-title", "portable-fingerprint", "full-content-hash", "file-resource-id", "file-size", "pixel-width", "pixel-height",
            "file-created", "file-modified", "availability", "date-added", "record-modified"
        ]
        let knownKeys = sourceKeys.union(
            BibliographicMetadataField.allCases.flatMap(\.markdownKeys)
        )

        for line in lines {
            if line == "### Finder notes" {
                section = .finderNotes
            } else if line == "### Personal notes" {
                section = .personalNotes
            } else if line.hasPrefix("## ") && section == .fields {
                continue
            } else if section == .fields, let field = MarkdownTokenizer.field(from: line) {
                if knownKeys.contains(field.key) {
                    fields[field.key, default: []].append(field.value)
                } else {
                    unrecognizedLines.append(line)
                }
            } else {
                switch section {
                case .fields:
                    if !line.isEmpty { unrecognizedLines.append(line) }
                case .finderNotes:
                    finderNoteLines.append(line.hasPrefix("> ") ? String(line.dropFirst(2)) : line)
                case .personalNotes:
                    personalNoteLines.append(line)
                }
            }
        }

        guard let relativePath = fields["source-file"]?.first, !relativePath.isEmpty,
              let sourceTitle = fields["source-title"]?.first, !sourceTitle.isEmpty else {
            throw CatalogError.catalogMalformed
        }

        let filename = (relativePath as NSString).lastPathComponent
        let source = SourceFileMetadata(
            relativePath: relativePath,
            filename: filename,
            sourceTitle: sourceTitle,
            finderComment: finderNoteLines.isEmpty ? nil : finderNoteLines.joined(separator: "\n"),
            portableFingerprint: fields["portable-fingerprint"]?.first,
            fullContentHash: fields["full-content-hash"]?.first,
            fileResourceIdentifier: fields["file-resource-id"]?.first,
            fileSize: parseInt64(fields["file-size"]?.first, key: "file-size", id: id, line: startLine, diagnostics: &diagnostics),
            pixelWidth: parseInt(fields["pixel-width"]?.first, key: "pixel-width", id: id, line: startLine, diagnostics: &diagnostics),
            pixelHeight: parseInt(fields["pixel-height"]?.first, key: "pixel-height", id: id, line: startLine, diagnostics: &diagnostics),
            fileCreationDate: parseDate(fields["file-created"]?.first, key: "file-created", diagnostics: &diagnostics, recordID: id, line: startLine),
            fileModificationDate: parseDate(fields["file-modified"]?.first, key: "file-modified", diagnostics: &diagnostics, recordID: id, line: startLine)
        )

        let bibliography = BibliographicMetadata(
            isbn10: fields["isbn-10"]?.first,
            isbn13: fields["isbn-13"]?.first,
            title: fields["bibliographic-title"]?.first,
            subtitle: fields["subtitle"]?.first,
            authors: fields["author"] ?? [],
            translators: fields["translator"] ?? [],
            contributors: (fields["contributor"] ?? []).compactMap(parseContributor),
            publisher: fields["publisher"]?.first,
            collectionName: fields["collection"]?.first,
            collectionNumber: fields["collection-number"]?.first,
            publicationPlace: fields["publication-place"]?.first,
            publicationDate: fields["published"]?.first,
            originalPublicationDate: fields["original-published"]?.first,
            editionDescription: fields["edition"]?.first,
            volumeDescription: fields["volume"]?.first,
            languageCode: fields["language"]?.first,
            additionalLanguageCodes: fields["additional-language"] ?? [],
            originalLanguageCode: fields["original-language"]?.first,
            pageCount: parseInt(fields["pages"]?.first, key: "pages", id: id, line: startLine, diagnostics: &diagnostics),
            paginationStatus: fields["pagination"]?.first.flatMap(PaginationStatus.init(rawValue:)),
            physicalAttributes: (fields["physical-attribute"] ?? []).compactMap(PhysicalAttribute.init(rawValue:)),
            subjects: fields["subject"] ?? [],
            description: fields["description"]?.first,
            openLibraryEditionID: fields["open-library-edition-id"]?.first,
            openLibraryWorkID: fields["open-library-work-id"]?.first,
            metadataSource: fields["metadata-source"]?.first.flatMap(MetadataSource.init(rawValue:)),
            metadataRetrievedAt: parseDate(fields["metadata-retrieved"]?.first, key: "metadata-retrieved", diagnostics: &diagnostics, recordID: id, line: startLine),
            metadataConfirmedByUser: fields["metadata-confirmed"]?.first == "true"
        )

        let availability = fields["availability"]?.first.flatMap(ItemAvailability.init(rawValue:)) ?? .available
        let dateAdded = parseDate(fields["date-added"]?.first, key: "date-added", diagnostics: &diagnostics, recordID: id, line: startLine) ?? .distantPast
        let dateModified = parseDate(fields["record-modified"]?.first, key: "record-modified", diagnostics: &diagnostics, recordID: id, line: startLine) ?? dateAdded

        return CatalogItem(
            id: id,
            source: source,
            bibliography: bibliography,
            personalNotes: personalNoteLines.joined(separator: "\n").trimmingCharacters(in: .newlines),
            dateAdded: dateAdded,
            dateModified: dateModified,
            availability: availability,
            unrecognizedLines: unrecognizedLines
        )
    }

    private func parseDate(
        _ value: String?,
        key: String,
        diagnostics: inout [MarkdownDiagnostic],
        recordID: UUID? = nil,
        line: Int? = nil
    ) -> Date? {
        guard let value else { return nil }
        guard let date = CatalogDateFormatter.date(from: value) else {
            diagnostics.append(.init(severity: .warning, code: .invalidDate, line: line, recordID: recordID, message: "An invalid \(key) date was ignored."))
            return nil
        }
        return date
    }

    private func parseContributor(_ value: String) -> BibliographicContributor? {
        guard let separator = value.range(of: " | ") else { return nil }
        let roles = value[..<separator.lowerBound]
            .split(separator: ",")
            .compactMap { ContributorRole(rawValue: String($0)) }
        let name = String(value[separator.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !roles.isEmpty, !name.isEmpty else { return nil }
        return BibliographicContributor(name: name, roles: roles)
    }

    private func parseInt(
        _ value: String?, key: String, id: UUID, line: Int, diagnostics: inout [MarkdownDiagnostic]
    ) -> Int? {
        guard let value else { return nil }
        guard let number = Int(value) else {
            diagnostics.append(.init(severity: .warning, code: .invalidFieldValue, line: line, recordID: id, message: "An invalid \(key) value was ignored."))
            return nil
        }
        return number
    }

    private func parseInt64(
        _ value: String?, key: String, id: UUID, line: Int, diagnostics: inout [MarkdownDiagnostic]
    ) -> Int64? {
        guard let value else { return nil }
        guard let number = Int64(value) else {
            diagnostics.append(.init(severity: .warning, code: .invalidFieldValue, line: line, recordID: id, message: "An invalid \(key) value was ignored."))
            return nil
        }
        return number
    }
}
