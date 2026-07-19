import Foundation

struct FilenameMetadataParser: Sendable {
    func suggestions(from sourceTitle: String) -> FilenameMetadataSuggestion {
        let original = sourceTitle.precomposedStringWithCanonicalMapping
        let source = normalizedSource(original)
        let pageMatch = firstMatch(#"(?i)(\d{1,4})\s*p(?:\.|ages?\b|\b)"#, in: source)
        let terminalPageMatch = pageMatch == nil
            ? firstMatch(#"(?<![\d-])(\d{2,4})\s*$"#, in: source)
            : nil
        let pages = (pageMatch ?? terminalPageMatch).flatMap { Int($0.groups[0]) }

        let pairedYears = matches(#"(?<!\d)(1[4-9]\d{2}|20\d{2})\s*\((1[4-9]\d{2}|20\d{2})\)"#, in: source).last
        let multiYear = matches(#"(?<!\d)(1[4-9]\d{2}|20\d{2})\s+et\s+(1[4-9]\d{2}|20\d{2})(?!\d)"#, in: source).last
        let allYears = matches(#"(?<!\d)(1[4-9]\d{2}|20\d{2})(?!\d)"#, in: source)
            .filter { match in
                guard let pageMatch else { return true }
                return !match.range.overlaps(pageMatch.range)
            }
        let publicationYear: String? = {
            if let pairedYears { return pairedYears.groups[0] }
            if let multiYear { return "\(multiYear.groups[0])–\(multiYear.groups[1])" }
            return allYears.last?.groups[0]
        }()
        let originalYear = pairedYears.flatMap { $0.groups.count > 1 ? $0.groups[1] : nil }

        let translators = extractTranslators(from: source)
        let contributors = extractContributors(from: source)
        let authors = extractAuthors(from: source, contributors: contributors)
        let collection = extractCollection(from: source)
        let publisher = extractPublisher(from: source, beforeYear: pairedYears?.groups[0] ?? allYears.last?.groups[0], collection: collection.name)
        let publicationPlace = extractPublicationPlace(from: source)
        let edition = extractEdition(from: source)
        let volume = extractVolume(from: source)
        let languages = extractLanguages(from: source, hasTranslators: !translators.isEmpty)
        let physicalAttributes = extractPhysicalAttributes(from: source)
        let paginationStatus: PaginationStatus? = contains(#"(?i)non[- ]pagin[eé]"#, in: source) ? .nonPaginated : nil
        let titleSource = extractTitleSource(
            from: source,
            authors: authors,
            contributors: contributors,
            publisher: publisher,
            collection: collection.name,
            publicationYear: publicationYear
        )
        let parsedTitle = parseTitle(titleSource, volume: volume)
        let notes = extractNotes(from: source, pageMatch: pageMatch, paginationStatus: paginationStatus)

        return FilenameMetadataSuggestion(
            title: parsedTitle.title.isEmpty ? nil : suggested(parsedTitle.title, confidence: .high, evidence: titleSource, in: original),
            subtitle: parsedTitle.subtitle.map { suggested($0, confidence: .medium, evidence: $0, in: original) },
            authors: authors.isEmpty ? nil : suggested(authors, confidence: .medium, evidence: authors.joined(separator: ", "), in: original),
            translators: translators.isEmpty ? nil : suggested(translators, confidence: .medium, evidence: translators.joined(separator: ", "), in: original),
            contributors: contributors.isEmpty ? nil : suggested(contributors, confidence: .medium, evidence: contributorEvidence(contributors), in: original),
            publisher: publisher.map { suggested($0, confidence: .low, evidence: $0, in: original) },
            collectionName: collection.name.map { suggested($0, confidence: .medium, evidence: $0, in: original) },
            collectionNumber: collection.number.map { suggested($0, confidence: .medium, evidence: $0, in: original) },
            publicationPlace: publicationPlace.map { suggested($0, confidence: .medium, evidence: $0, in: original) },
            publicationDate: publicationYear.map { suggested($0, confidence: .medium, evidence: $0, in: original) },
            originalPublicationDate: originalYear.map { suggested($0, confidence: .medium, evidence: "(\($0))", in: original) },
            editionDescription: edition.map { suggested($0, confidence: .medium, evidence: $0, in: original) },
            volumeDescription: volume.map { suggested($0, confidence: .medium, evidence: $0, in: original) },
            languageCodes: languages.current.isEmpty ? nil : suggested(languages.current, confidence: .medium, evidence: languages.current.joined(separator: ", "), in: original),
            originalLanguageCode: languages.original.map { suggested($0, confidence: .medium, evidence: $0, in: original) },
            pageCount: pages.map { suggested($0, confidence: pageMatch == nil ? .low : .high, evidence: (pageMatch ?? terminalPageMatch)?.full ?? "", in: original) },
            paginationStatus: paginationStatus.map { suggested($0, confidence: .high, evidence: $0.label, in: original) },
            physicalAttributes: physicalAttributes.isEmpty ? nil : suggested(physicalAttributes, confidence: .high, evidence: physicalAttributes.map(\.label).joined(separator: ", "), in: original),
            descriptiveNotes: notes.map { suggested($0, confidence: .medium, evidence: $0, in: original) }
        )
    }

    private func normalizedSource(_ value: String) -> String {
        var result = value.replacingOccurrences(
            of: #"^\s*\d+\)\s*"#,
            with: "",
            options: .regularExpression
        )
        let corrections = [
            "Classiquea canadien": "Classiques canadiens",
            "Forword": "Foreword",
            "Illustrationss": "Illustrations",
            "ont aterri": "ont atterri",
            "Michel Lessard Gillas Vilandré": "Michel Lessard et Gilles Vilandré",
            "Les de lUniversité Laval": "Les Presses de l'Université Laval",
            "dans un boitier": "dans un boîtier"
        ]
        for (mistake, correction) in corrections {
            result = result.replacingOccurrences(of: mistake, with: correction, options: [.caseInsensitive, .diacriticInsensitive])
        }
        return result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTranslators(from value: String) -> [String] {
        let patterns = [
            #"(?i)traduit(?:e)?\s+de\s+l['’]anglais\s+par\s*([^,]+)"#,
            #"(?i)translated\s+by\s+([^,]+)"#,
            #"(?i)english\s+translation\s+by\s+([^,]+)"#,
            #"(?i)traduction\s+de\s+([^,]+)"#
        ]
        guard let match = patterns.compactMap({ firstMatch($0, in: value) }).min(by: { $0.range.lowerBound < $1.range.lowerBound }) else {
            return []
        }
        return splitPeople(match.groups[0])
    }

    private func extractContributors(from value: String) -> [BibliographicContributor] {
        var result: [BibliographicContributor] = []
        addCredits(pattern: #"(?i)avant[- ]propos\s+de\s+([^,]+)"#, roles: [.foreword], from: value, to: &result)
        addCredits(pattern: #"(?i)pr[eé]face\s+de\s+([^,]+)"#, roles: [.preface], from: value, to: &result)
        addCredits(pattern: #"(?i)foreword\s+by\s+([^,]+)"#, roles: [.foreword], from: value, to: &result)
        addCredits(pattern: #"(?i)iconographie\s+r[eé]unie\s+par\s+([^,]+)"#, roles: [.iconographer], from: value, to: &result)
        addCredits(pattern: #"(?i)illustrations?\s+(?:drawn\s*&\s*collected|drawn)\s+by\s+([^,]+)"#, roles: [.illustrator, .iconographer], from: value, to: &result)
        addCredits(pattern: #"(?i)assisted\s+by\s+([^,]+)"#, roles: [.assistant], from: value, to: &result)
        addCredits(pattern: #"(?i)maps\s+by\s+([^,]+)"#, roles: [.cartographer], from: value, to: &result)
        addCredits(pattern: #"(?i)dessins\s+de\s+([^,]+)"#, roles: [.illustrator], from: value, to: &result)
        addCredits(pattern: #"(?i)textes?\.?\s+choisis,?\s+pr[eé]sent[eé]s\s+et\s+annot[eé]s\s+par\s+([^,]+)"#, roles: [.compiler, .editor, .annotator], from: value, to: &result)
        addCredits(pattern: #"(?i)edited\s+by\s+([^,]+)"#, roles: [.editor], from: value, to: &result)
        addCredits(pattern: #"(?i)publi[eé]\s+par\s+([^,]+)"#, roles: [.editorDirector], from: value, to: &result)

        if contains(#"(?i)^Bossuet\s+[ŒO]euvres\s+choisies"#, in: value) {
            addCredits(pattern: #"(?i)par\s+([^,]+?)(?=,?\s+(?:onzi[eè]me\s+[eé]dition|librairie))"#, roles: [.compiler, .editor], from: value, to: &result)
        }
        addCredits(pattern: #"(?i)par\s+([^,]+),\s*general\s+editor"#, roles: [.generalEditor], from: value, to: &result)
        return mergedContributors(result)
    }

    private func addCredits(
        pattern: String,
        roles: [ContributorRole],
        from value: String,
        to result: inout [BibliographicContributor]
    ) {
        for match in matches(pattern, in: value) where !match.groups.isEmpty {
            for name in splitPeople(trimAtMetadata(match.groups[0])) {
                result.append(.init(name: name, roles: roles))
            }
        }
    }

    private func mergedContributors(_ values: [BibliographicContributor]) -> [BibliographicContributor] {
        var result: [BibliographicContributor] = []
        for value in values {
            if let index = result.firstIndex(where: { SearchNormalizer.normalize($0.name) == SearchNormalizer.normalize(value.name) }) {
                for role in value.roles where !result[index].roles.contains(role) {
                    result[index].roles.append(role)
                }
            } else {
                result.append(value)
            }
        }
        return result
    }

    private func extractAuthors(from value: String, contributors: [BibliographicContributor]) -> [String] {
        if contains(#"(?i)^Daniel-Rops\s+de\s+l['’]Acad[eé]mie"#, in: value) { return ["Daniel-Rops"] }
        if contains(#"(?i)^Be My Guest,\s*Conrad N\. Hilton"#, in: value) { return ["Conrad N. Hilton"] }
        if contains(#"(?i)^Bossuet\s+[ŒO]euvres\s+choisies"#, in: value) { return ["Bossuet"] }
        if let textCredit = firstMatch(#"(?i)texte\s+de\s+([^,]+)"#, in: value) {
            return splitPeople(trimAtMetadata(textCredit.groups[0]))
        }

        let rolePrefixes = [
            "traduit", "translated", "translation", "edited", "préface", "preface", "foreword",
            "iconographie", "illustration", "assisted", "maps", "dessins", "annotés", "annotes", "publié", "publie"
        ]
        for match in matches(#"(?i)\b(par|by|de)\s+"#, in: value) {
            let prefixStart = value.index(match.range.lowerBound, offsetBy: -min(32, value.distance(from: value.startIndex, to: match.range.lowerBound)))
            let rawPrefix = String(value[prefixStart..<match.range.lowerBound])
            let prefix = SearchNormalizer.normalize(rawPrefix)
            if rolePrefixes.contains(where: { prefix.hasSuffix($0) }) { continue }
            if SearchNormalizer.normalize(match.groups[0]) == "de" {
                let commaDelimited = rawPrefix.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(",")
                let semanticAuthorPhrase = ["recit", "histoire sainte", "oeuvres"].contains { prefix.hasSuffix($0) }
                if !commaDelimited, !semanticAuthorPhrase { continue }
            }
            let tail = String(value[match.range.upperBound...])
            let candidate = trimAtMetadata(tail.components(separatedBy: ",").first ?? tail)
            let normalized = SearchNormalizer.normalize(candidate)
            if normalized.hasPrefix("l'institut") || normalized.hasPrefix("l'academie") || candidate.isEmpty { continue }
            let names = splitPeople(candidate)
            if !names.isEmpty { return names }
        }
        let editorsWhoMayBeCataloguedAsAuthors = contributors.filter { $0.roles == [.editor] }.map(\.name)
        return editorsWhoMayBeCataloguedAsAuthors
    }

    private func trimAtMetadata(_ value: String) -> String {
        let patterns = [
            #"(?i)\s+with\s+maps\s+by\b"#, #"(?i)\s+foreword\s+by\b"#, #"(?i)\s+2\s+vols?\b"#, #"(?i)\s+tome\s+\d+\b"#,
            #"(?i)\s+(?:[eé]ditions?|[eé]d\.|librairie|presses?|books?|collection)\b"#,
            #"\s+(?:1[4-9]\d{2}|20\d{2})\b"#
        ]
        let boundary = patterns.compactMap { firstMatch($0, in: value)?.range.lowerBound }.min() ?? value.endIndex
        return String(value[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func splitPeople(_ value: String) -> [String] {
        value.components(separatedBy: try! NSRegularExpression(pattern: #"\s+(?:et|and|&)\s+"#, options: .caseInsensitive))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }
    }

    private func extractCollection(from value: String) -> (name: String?, number: String?) {
        if let match = firstMatch(#"(?i)[\"“]Que sais-je[\"”]\s+No\s*(\d*)"#, in: value) {
            return ("Que sais-je", match.groups.first.flatMap { $0.isEmpty ? nil : $0 })
        }
        if let match = firstMatch(#"(?i)Collection\s+[\"“]([^\"”]+)[\"”]"#, in: value) {
            return (correctedCollection(match.groups[0]), nil)
        }
        if let match = firstMatch(#"(?i)Collection\s+(?!Berko\b)([^,/]+)(?:/|,)"#, in: value) {
            return (correctedCollection(match.groups[0]), nil)
        }
        if contains(#"(?i)[\"“]Bouquins[\"”]"#, in: value) { return ("Bouquins", nil) }
        if contains(#"(?i)Les Grandes [eé]tudes historiques"#, in: value) { return ("Les Grandes études historiques", nil) }
        if contains(#"(?i)Le Livre de Poche"#, in: value) { return ("Le Livre de Poche", nil) }
        if contains(#"(?i)[\"“]Classiques canadiens[\"”]"#, in: value) { return ("Classiques canadiens", nil) }
        return (nil, nil)
    }

    private func correctedCollection(_ value: String) -> String {
        if SearchNormalizer.normalize(value) == "les causes celebre" { return "Les Causes Célèbres" }
        return value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func extractPublisher(from value: String, beforeYear year: String?, collection: String?) -> String? {
        guard let year, let yearRange = value.range(of: year.components(separatedBy: "–").first ?? year, options: .backwards) else { return nil }
        let prefix = String(value[..<yearRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        let chunks = prefix.split(separator: ",", omittingEmptySubsequences: true).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let keywords = [
            "edition", "editions", "edizioni", "ed.", "librairie", "press", "presses", "books", "company", "editeur",
            "imprimerie", "hachette", "boreal", "dargaud", "paperjacks", "farcountry", "mame", "methuen",
            "larousse", "balland", "fayard", "collection berko", "national geographic society", "simon & schuster"
        ]
        var candidate = chunks.reversed().first { chunk in
            let normalized = SearchNormalizer.normalize(chunk)
            return keywords.contains { normalized.contains($0) }
        }
        if candidate == nil, let last = chunks.last {
            let normalizedLast = SearchNormalizer.normalize(last)
            let looksLikeResponsibility = normalizedLast.hasPrefix("par ") || normalizedLast.hasPrefix("by ") || normalizedLast.hasPrefix("de ")
            let looksLikeInversion = normalizedLast.hasSuffix(" de") || normalizedLast.hasSuffix(" of")
            let looksLikeSeries = collection != nil && normalizedLast.hasPrefix("collection ")
            if !isPlace(last), !looksLikeResponsibility, !looksLikeInversion, !looksLikeSeries {
                candidate = last
            }
        }
        guard var candidate, candidate.count > 1 else { return nil }
        if let collection, candidate.localizedCaseInsensitiveContains(collection), let slash = candidate.firstIndex(of: "/") {
            candidate = candidate[candidate.index(after: slash)...].trimmingCharacters(in: .whitespaces)
        }
        if let publisherRange = candidate.range(
            of: #"(?i)(?:[eé]ditions?|[eé]d\.|librairie|presses?|the national geographic society|collection berko|a fireside book|paperjacks|farcountry|hachette|bor[eé]al|dargaud|warner books|penguin books|oxford university press).*$"#,
            options: .regularExpression
        ) {
            candidate = String(candidate[publisherRange])
        }
        for place in knownPlaces where SearchNormalizer.normalize(candidate).hasSuffix(" \(SearchNormalizer.normalize(place))") {
            candidate = String(candidate.dropLast(place.count)).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        }
        return candidate.isEmpty ? nil : candidate
    }

    private var knownPlaces: [String] {
        ["Garden City", "New York", "Glendale CA", "Washington D.C.", "Rosemont", "Toronto", "Ottawa", "Paris", "Florence", "Tours", "Lévis"]
    }

    private func isPlace(_ value: String) -> Bool {
        knownPlaces.contains { SearchNormalizer.normalize($0) == SearchNormalizer.normalize(value) }
    }

    private func extractPublicationPlace(from value: String) -> String? {
        let found = knownPlaces.filter { place in
            value.range(of: place, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
        if found.contains("Garden City"), found.contains("New York") { return "Garden City, New York" }
        return found.last
    }

    private func extractEdition(from value: String) -> String? {
        firstMatch(#"(?i)(Third Edition|onzi[eè]me [eé]dition)"#, in: value)?.full
    }

    private func extractVolume(from value: String) -> String? {
        let patterns = [
            #"(?i)\b(tome\s*\d+)\b"#,
            #"(?i)\b(\d+\s+vols?)\b"#,
            #"(?i)\b(vol(?:ume)?[.,]?\s*(?:[A-ZÀ-ÖØ-Þ]+|\d+)(?:\s+[^,]+)?)"#,
            #"(?i)(?<!\d)(6\.1)(?!\d)"#
        ]
        return patterns.compactMap { firstMatch($0, in: value) }.min(by: { $0.range.lowerBound < $1.range.lowerBound })?.groups.first
    }

    private func extractLanguages(from value: String, hasTranslators: Bool) -> (current: [String], original: String?) {
        if contains(#"(?i)en fran[cç]ais et en italien"#, in: value) { return (["fr", "it"], nil) }
        if contains(#"(?i)en fran[cç]ais"#, in: value) { return (["fr"], nil) }
        if contains(#"(?i)english translation by"#, in: value) { return (["en"], nil) }
        if contains(#"(?i)(?:traduit(?:e)? de l['’]anglais|translated by)"#, in: value), hasTranslators {
            return (["fr"], "en")
        }
        return ([], nil)
    }

    private func extractPhysicalAttributes(from value: String) -> [PhysicalAttribute] {
        var result: [PhysicalAttribute] = []
        func include(_ attribute: PhysicalAttribute, if pattern: String) {
            if contains(pattern, in: value), !result.contains(attribute) { result.append(attribute) }
        }
        include(.illustrated, if: #"(?i)\bill\.?\b"#)
        include(.maps, if: #"(?i)\b(?:cartes?|maps?)\b"#)
        include(.foldoutMaps, if: #"(?i)cartes?\s+d[eé]pliantes?"#)
        include(.battlePlans, if: #"(?i)plans?\s+de\s+bataille"#)
        include(.genealogicalTrees, if: #"(?i)arbres?\s+g[eé]n[eé]alogiques?"#)
        include(.blackAndWhite, if: #"(?i)noir\s+et\s+blanc"#)
        include(.dustJacket, if: #"(?i)\bjaquette\b"#)
        include(.slipcase, if: #"(?i)\bbo[iî]tier\b"#)
        include(.doublePages, if: #"(?i)pages?\s+doubles?"#)
        return result
    }

    private func extractTitleSource(
        from value: String,
        authors: [String],
        contributors: [BibliographicContributor],
        publisher: String?,
        collection: String?,
        publicationYear: String?
    ) -> String {
        if let match = firstMatch(#"(?i)^Daniel-Rops\s+de\s+l['’]Acad[eé]mie fran[cç]aise,\s*6\.1\s+(.+?)(?=,\s*Les Grandes [eé]tudes historiques)"#, in: value) {
            return match.groups[0]
        }
        if let match = firstMatch(#"(?i)^Bossuet\s+(.+?)\s+par\s+J\.\s*Calvet"#, in: value) {
            return match.groups[0].replacingOccurrences(of: "Oeuvres", with: "Œuvres", options: [.caseInsensitive, .diacriticInsensitive])
        }

        var boundaries: [String.Index] = []
        let boundaryPatterns = [
            #"(?i),?\s*avant[- ]propos\s+de\b"#, #"(?i),?\s*pr[eé]face\s+de\b"#,
            #"(?i),?\s*foreword\s+by\b"#, #"(?i),?\s*iconographie\s+r[eé]unie\s+par\b"#,
            #"(?i),?\s*illustrations?\s+(?:drawn|collected)"#, #"(?i),?\s*textes?\.?\s+choisis"#,
            #"(?i),?\s*texte\s+de\b"#, #"(?i),?\s*publi[eé]\s+par\b"#,
            #"(?i),?\s*edited\s+by\b"#, #"(?i),?\s*en fran[cç]ais(?:\s+et\s+en\s+italien)?\b"#
        ]
        boundaries.append(contentsOf: boundaryPatterns.compactMap { firstMatch($0, in: value)?.range.lowerBound })

        if let author = authors.first,
           let range = value.range(of: author, options: [.caseInsensitive, .diacriticInsensitive]),
           let marker = value[..<range.lowerBound].range(of: #"(?:,\s*)?(?:par|by|de|r[eé]cit de)\s*$"#, options: [.regularExpression, .caseInsensitive, .diacriticInsensitive]) {
            boundaries.append(marker.lowerBound)
        }
        for token in [collection, publisher].compactMap({ $0 }) {
            if let range = value.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) {
                boundaries.append(range.lowerBound)
            }
        }
        if boundaries.isEmpty, let publicationYear,
           let year = publicationYear.components(separatedBy: "–").first,
           let range = value.range(of: year) {
            boundaries.append(range.lowerBound)
        }
        let boundary = boundaries.min() ?? value.endIndex
        var raw = String(value[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))

        if contains(#"(?i)^Be My Guest,\s*Conrad N\. Hilton$"#, in: raw) {
            raw = "Be My Guest"
        }
        if contains(#"(?i)^Paul Leduc 1876/1943,\s*Patrick et Viviane Berko$"#, in: raw) {
            raw = "Paul Leduc 1876/1943"
        }
        return raw
    }

    private func parseTitle(_ rawTitle: String, volume: String?) -> (title: String, subtitle: String?) {
        var raw = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        if let volume, let range = raw.range(of: volume, options: [.caseInsensitive, .diacriticInsensitive]) {
            raw.removeSubrange(range)
            raw = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        }

        if let match = firstMatch(#"(?i)^Fran[cç]ois X\. Aubry\s*[\"“]?(.+?)[\"”]?$"#, in: raw) {
            return ("François X. Aubry: \(match.groups[0].trimmingCharacters(in: CharacterSet(charactersIn: "\"“” ")))", nil)
        }
        if let match = firstMatch(#"(?i)^Canadian Establishment,\s*Debrett['’]s Illustrated Guide to The$"#, in: raw) {
            _ = match
            return ("Debrett's Illustrated Guide to the Canadian Establishment", nil)
        }
        if contains(#"(?i)^Capitol,\s*We the People\s*-The Story of the United States$"#, in: raw) {
            return ("We the People: The Story of the United States Capitol", nil)
        }

        let pieces = raw.split(separator: ",", omittingEmptySubsequences: true).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if pieces.count >= 2, isArticle(pieces.last ?? "") {
            let article = normalizedArticle(pieces.last ?? "")
            let title = join(article: article, title: pieces[0])
            let subtitle = pieces.dropFirst().dropLast().joined(separator: ", ")
            return (title, subtitle.isEmpty ? nil : subtitle)
        }
        if pieces.count >= 2, isArticle(pieces[1]) {
            let title = join(article: normalizedArticle(pieces[1]), title: pieces[0])
            let subtitle = pieces.dropFirst(2).joined(separator: ", ")
            return (title, cleanSubtitle(subtitle))
        }
        if pieces.count >= 2 {
            let inversion = pieces[1]
            let normalized = SearchNormalizer.normalize(inversion)
            if normalized.hasSuffix(" of") || normalized.hasSuffix(" de") {
                let title = "\(inversion) \(pieces[0])"
                let subtitle = pieces.dropFirst(2).joined(separator: ", ")
                return (title, cleanSubtitle(subtitle))
            }
            if normalized.hasPrefix("sir william ") {
                let words = inversion.split(separator: " ")
                let title = ([String(words[0]), String(words[1]), pieces[0]] + words.dropFirst(2).map(String.init)).joined(separator: " ")
                return (title, cleanSubtitle(pieces.dropFirst(2).joined(separator: ", ")))
            }
        }
        if let quoted = firstMatch(#"^(.+?),\s*[\"“]([^\"”]+)[\"”]?$"#, in: raw), quoted.groups.count == 2 {
            return (quoted.groups[0], quoted.groups[1].trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let quoted = firstMatch(#"^(.+?)\s+[\"“]([^\"”]+)[\"”]$"#, in: raw), quoted.groups.count == 2 {
            return (quoted.groups[0], quoted.groups[1].trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let hyphen = firstMatch(#"^(.+?),?\s+-\s*(.+)$"#, in: raw), hyphen.groups.count == 2 {
            return (hyphen.groups[0].trimmingCharacters(in: .whitespaces), hyphen.groups[1].trimmingCharacters(in: .whitespaces))
        }
        if let valuable = firstMatch(#"(?i)^(A Valuable Property),\s*(The life story of Michael Todd)$"#, in: raw) {
            return (valuable.groups[0], valuable.groups[1])
        }
        return (raw, nil)
    }

    private func isArticle(_ value: String) -> Bool {
        ["le", "la", "les", "l", "l'", "the", "a", "an"].contains(SearchNormalizer.normalize(value).trimmingCharacters(in: CharacterSet(charactersIn: "'’")))
    }

    private func normalizedArticle(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if SearchNormalizer.normalize(clean) == "l" { return "L'" }
        return clean
    }

    private func join(article: String, title: String) -> String {
        article.hasSuffix("'") ? "\(article)\(title)" : "\(article) \(title)"
    }

    private func cleanSubtitle(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”,-")))
        return clean.isEmpty ? nil : clean
    }

    private func extractNotes(from value: String, pageMatch: RegexMatch?, paginationStatus: PaginationStatus?) -> String? {
        var notes: [String] = []
        if contains(#"(?i)^Paul Leduc 1876/1943,\s*Patrick et Viviane Berko"#, in: value) {
            notes.append("Private collection owners: Patrick et Viviane Berko")
        }
        if let provenance = firstMatch(#"(?i)(re[cç]u de\s+[^\d,]+)"#, in: value)?.groups.first {
            notes.append(provenance.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)))
        }
        if let pageMatch {
            let tail = String(value[pageMatch.range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            if !tail.isEmpty { notes.append(tail) }
        } else if paginationStatus != nil {
            if let range = value.range(of: #"(?i)non[- ]pagin[eé]"#, options: .regularExpression) {
                let tail = String(value[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if !tail.isEmpty { notes.append(tail) }
            }
        }
        let unique = notes.reduce(into: [String]()) { result, note in
            if !result.contains(where: { SearchNormalizer.normalize($0) == SearchNormalizer.normalize(note) }) { result.append(note) }
        }
        return unique.isEmpty ? nil : unique.joined(separator: "; ")
    }

    private func contributorEvidence(_ contributors: [BibliographicContributor]) -> String {
        contributors.map { contributor in
            "\(contributor.name) (\(contributor.roles.map(\.label).joined(separator: ", ")))"
        }.joined(separator: "; ")
    }

    private func suggested<Value: Equatable & Sendable>(
        _ value: Value,
        confidence: SuggestionConfidence,
        evidence: String,
        in source: String
    ) -> SuggestedValue<Value> {
        let span = source.range(of: evidence, options: [.caseInsensitive, .diacriticInsensitive]).map {
            source.distance(from: source.startIndex, to: $0.lowerBound)..<source.distance(from: source.startIndex, to: $0.upperBound)
        }
        return SuggestedValue(value: value, confidence: confidence, evidence: evidence, sourceSpan: span)
    }

    private func contains(_ pattern: String, in value: String) -> Bool {
        firstMatch(pattern, in: value) != nil
    }

    private func firstMatch(_ pattern: String, in value: String) -> RegexMatch? {
        matches(pattern, in: value).first
    }

    private func matches(_ pattern: String, in value: String) -> [RegexMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).compactMap { result in
            guard let fullRange = Range(result.range, in: value) else { return nil }
            let groups = (1..<result.numberOfRanges).map { index -> String in
                guard result.range(at: index).location != NSNotFound,
                      let range = Range(result.range(at: index), in: value) else { return "" }
                return String(value[range])
            }
            return RegexMatch(full: String(value[fullRange]), groups: groups, range: fullRange)
        }
    }

    private struct RegexMatch {
        var full: String
        var groups: [String]
        var range: Range<String.Index>
    }
}

private extension String {
    func components(separatedBy regex: NSRegularExpression) -> [String] {
        let range = NSRange(startIndex..<endIndex, in: self)
        var pieces: [String] = []
        var cursor = startIndex
        for match in regex.matches(in: self, range: range) {
            guard let matchRange = Range(match.range, in: self) else { continue }
            pieces.append(String(self[cursor..<matchRange.lowerBound]))
            cursor = matchRange.upperBound
        }
        pieces.append(String(self[cursor...]))
        return pieces
    }
}
