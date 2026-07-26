import CryptoKit
import Foundation

struct RulePackageManifest: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let packageVersion: String
    let parserEngineVersion: String
    let resourceDigests: [String: String]
}

enum FieldConfidence: String, Codable, Sendable {
    case mechanical
    case heuristic
    case unresolved
}

struct ParsingRuleDefinition: Codable, Sendable, Equatable {
    let id: String
    let category: String
    let pattern: String
    let precedence: Int
    let specificity: Int
    let confidence: FieldConfidence
    let negativeGuards: [String]
    let version: String
    var canonicalValue: String?
    var roles: [String]?
}

struct CorrectionRuleDefinition: Codable, Sendable, Equatable {
    let id: String
    let match: String
    let replacement: String
    let matchMode: String
    let languageScope: String?
    let introducedVersion: String
}

struct NormalizationAliasDefinition: Codable, Sendable, Equatable {
    let id: String
    let category: String
    let match: String
    let canonicalValue: String
    let version: String
}

struct DecodedRulePackage: Sendable, Equatable {
    let manifest: RulePackageManifest
    let corrections: [CorrectionRuleDefinition]
    let contributorMarkers: [ParsingRuleDefinition]
    let inversionMarkers: [ParsingRuleDefinition]
    let collectionMarkers: [ParsingRuleDefinition]
    let lexicalMarkers: [ParsingRuleDefinition]
    let aliases: [NormalizationAliasDefinition]
}

struct CompiledParsingRule: @unchecked Sendable {
    let definition: ParsingRuleDefinition
    let regex: NSRegularExpression
    let negativeGuards: [NSRegularExpression]
}

struct CompiledCorrectionRule: @unchecked Sendable {
    let definition: CorrectionRuleDefinition
    let regex: NSRegularExpression?
}

struct CompiledAliasRule: @unchecked Sendable {
    let definition: NormalizationAliasDefinition
    let regex: NSRegularExpression
}

struct ParsingConfiguration: @unchecked Sendable {
    let manifest: RulePackageManifest
    let corrections: [CompiledCorrectionRule]
    let contributorMarkers: [CompiledParsingRule]
    let inversionMarkers: [CompiledParsingRule]
    let collectionMarkers: [CompiledParsingRule]
    let lexicalMarkers: [CompiledParsingRule]
    let aliases: [NormalizationAliasDefinition]
    let languageSourcePatterns: [CompiledAliasRule]
    private let rulesByCategory: [String: [CompiledParsingRule]]

    init(
        manifest: RulePackageManifest,
        corrections: [CompiledCorrectionRule],
        contributorMarkers: [CompiledParsingRule],
        inversionMarkers: [CompiledParsingRule],
        collectionMarkers: [CompiledParsingRule],
        lexicalMarkers: [CompiledParsingRule],
        aliases: [NormalizationAliasDefinition],
        languageSourcePatterns: [CompiledAliasRule],
        rulesByCategory: [String: [CompiledParsingRule]]
    ) {
        self.manifest = manifest
        self.corrections = corrections
        self.contributorMarkers = contributorMarkers
        self.inversionMarkers = inversionMarkers
        self.collectionMarkers = collectionMarkers
        self.lexicalMarkers = lexicalMarkers
        self.aliases = aliases
        self.languageSourcePatterns = languageSourcePatterns
        self.rulesByCategory = rulesByCategory
    }

    static let bundled: ParsingConfiguration = {
        do {
            return try RulePackageLoader().load()
        } catch {
            preconditionFailure("Invalid bundled filename parsing rules: \(error)")
        }
    }()

    func rules(category: String) -> [CompiledParsingRule] {
        rulesByCategory[category] ?? []
    }

    func alias(category: String, value: String) -> String {
        aliases.first {
            $0.category == category &&
                SearchNormalizer.normalize($0.match) == SearchNormalizer.normalize(value)
        }?.canonicalValue ?? value
    }
}

enum RulePackageError: Error, Equatable, CustomStringConvertible {
    case missingResource(String)
    case unsupportedSchema(Int)
    case unsupportedEngine(String)
    case digestMismatch(String)
    case duplicateRuleID(String)
    case invalidRuleID(String)
    case invalidRegex(String)
    case invalidMatchMode(String)
    case precedenceConflict(String, String)
    case contradictoryAlias(String)

    var description: String {
        switch self {
        case .missingResource(let name): "Missing resource \(name)"
        case .unsupportedSchema(let version): "Unsupported schema \(version)"
        case .unsupportedEngine(let version): "Unsupported engine \(version)"
        case .digestMismatch(let name): "Digest mismatch for \(name)"
        case .duplicateRuleID(let id): "Duplicate rule ID \(id)"
        case .invalidRuleID(let id): "Invalid rule ID \(id)"
        case .invalidRegex(let id): "Invalid regex for \(id)"
        case .invalidMatchMode(let mode): "Invalid correction match mode \(mode)"
        case .precedenceConflict(let first, let second): "Precedence conflict between \(first) and \(second)"
        case .contradictoryAlias(let value): "Contradictory alias \(value)"
        }
    }
}

struct RulePackageLoader: Sendable {
    static let resourceNames = [
        "correction-rules.json",
        "contributor-markers.json",
        "inversion-markers.json",
        "collection-markers.json",
        "lexical-markers.json",
        "normalization-aliases.json",
    ]

    private let bundle: Bundle
    private let decoder = JSONDecoder()

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func load() throws -> ParsingConfiguration {
        let manifestData = try data(named: "manifest.json")
        let manifest = try decoder.decode(RulePackageManifest.self, from: manifestData)
        var resources: [String: Data] = [:]
        for name in Self.resourceNames {
            resources[name] = try data(named: name)
        }
        return try Self.makeConfiguration(manifest: manifest, resources: resources)
    }

    static func makeConfiguration(
        manifest: RulePackageManifest,
        resources: [String: Data],
        validateDigests: Bool = true
    ) throws -> ParsingConfiguration {
        let decoder = JSONDecoder()
        let package = DecodedRulePackage(
            manifest: manifest,
            corrections: try decode([CorrectionRuleDefinition].self, named: "correction-rules.json", from: resources, decoder: decoder),
            contributorMarkers: try decode([ParsingRuleDefinition].self, named: "contributor-markers.json", from: resources, decoder: decoder),
            inversionMarkers: try decode([ParsingRuleDefinition].self, named: "inversion-markers.json", from: resources, decoder: decoder),
            collectionMarkers: try decode([ParsingRuleDefinition].self, named: "collection-markers.json", from: resources, decoder: decoder),
            lexicalMarkers: try decode([ParsingRuleDefinition].self, named: "lexical-markers.json", from: resources, decoder: decoder),
            aliases: try decode([NormalizationAliasDefinition].self, named: "normalization-aliases.json", from: resources, decoder: decoder)
        )
        try RulePackageValidator().validate(package, resources: resources, validateDigests: validateDigests)
        return try compile(package)
    }

    private func data(named filename: String) throws -> Data {
        let stem = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let candidates = [
            bundle.url(forResource: stem, withExtension: ext, subdirectory: "ParsingRules"),
            bundle.url(forResource: stem, withExtension: ext, subdirectory: "Resources/ParsingRules"),
            bundle.url(forResource: stem, withExtension: ext),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            throw RulePackageError.missingResource(filename)
        }
        return try Data(contentsOf: url)
    }

    private static func decode<Value: Decodable>(
        _ type: Value.Type,
        named name: String,
        from resources: [String: Data],
        decoder: JSONDecoder
    ) throws -> Value {
        guard let data = resources[name] else { throw RulePackageError.missingResource(name) }
        return try decoder.decode(type, from: data)
    }

    private static func compile(_ package: DecodedRulePackage) throws -> ParsingConfiguration {
        func compiled(_ definitions: [ParsingRuleDefinition]) throws -> [CompiledParsingRule] {
            try definitions.map { definition in
                do {
                    return CompiledParsingRule(
                        definition: definition,
                        regex: try NSRegularExpression(pattern: definition.pattern),
                        negativeGuards: try definition.negativeGuards.map {
                            try NSRegularExpression(pattern: $0)
                        }
                    )
                } catch {
                    throw RulePackageError.invalidRegex(definition.id)
                }
            }
        }
        let corrections = try package.corrections.map { definition -> CompiledCorrectionRule in
            switch definition.matchMode {
            case "case-diacritic-insensitive-literal":
                return CompiledCorrectionRule(definition: definition, regex: nil)
            case "regular-expression":
                do {
                    return CompiledCorrectionRule(
                        definition: definition,
                        regex: try NSRegularExpression(pattern: definition.match)
                    )
                } catch {
                    throw RulePackageError.invalidRegex(definition.id)
                }
            default:
                throw RulePackageError.invalidMatchMode(definition.matchMode)
            }
        }
        let contributorMarkers = try compiled(package.contributorMarkers)
        let inversionMarkers = try compiled(package.inversionMarkers)
        let collectionMarkers = try compiled(package.collectionMarkers)
        let lexicalMarkers = try compiled(package.lexicalMarkers)
        let allRules = contributorMarkers + inversionMarkers + collectionMarkers + lexicalMarkers
        let rulesByCategory = Dictionary(grouping: allRules, by: \.definition.category)
            .mapValues { rules in
                rules.sorted {
                    if $0.definition.precedence != $1.definition.precedence {
                        return $0.definition.precedence > $1.definition.precedence
                    }
                    if $0.definition.specificity != $1.definition.specificity {
                        return $0.definition.specificity > $1.definition.specificity
                    }
                    return $0.definition.id < $1.definition.id
                }
            }
        return ParsingConfiguration(
            manifest: package.manifest,
            corrections: corrections,
            contributorMarkers: contributorMarkers,
            inversionMarkers: inversionMarkers,
            collectionMarkers: collectionMarkers,
            lexicalMarkers: lexicalMarkers,
            aliases: package.aliases,
            languageSourcePatterns: try package.aliases
                .filter { $0.category == "language" }
                .map { alias in
                    CompiledAliasRule(
                        definition: alias,
                        regex: try NSRegularExpression(
                            pattern: "(?i)(?:traduction|traduit(?:e)?)\\s+de\\s+l['’]\(NSRegularExpression.escapedPattern(for: alias.match))"
                        )
                    )
                },
            rulesByCategory: rulesByCategory
        )
    }
}

struct RulePackageValidator: Sendable {
    func validate(
        _ package: DecodedRulePackage,
        resources: [String: Data],
        validateDigests: Bool = true
    ) throws {
        guard package.manifest.schemaVersion == 1 else {
            throw RulePackageError.unsupportedSchema(package.manifest.schemaVersion)
        }
        guard package.manifest.parserEngineVersion == "2.1.0" else {
            throw RulePackageError.unsupportedEngine(package.manifest.parserEngineVersion)
        }
        if validateDigests {
            for name in RulePackageLoader.resourceNames {
                guard let data = resources[name] else { throw RulePackageError.missingResource(name) }
                let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                guard package.manifest.resourceDigests[name] == actual else {
                    throw RulePackageError.digestMismatch(name)
                }
            }
        }

        let parsingRules = package.contributorMarkers + package.inversionMarkers +
            package.collectionMarkers + package.lexicalMarkers
        let allIDs = package.corrections.map(\.id) + parsingRules.map(\.id) + package.aliases.map(\.id)
        var seen = Set<String>()
        for id in allIDs {
            guard id.range(of: #"^[a-z0-9]+(?:[.-][a-z0-9]+)+$"#, options: .regularExpression) != nil else {
                throw RulePackageError.invalidRuleID(id)
            }
            guard seen.insert(id).inserted else { throw RulePackageError.duplicateRuleID(id) }
        }

        for rule in parsingRules {
            do {
                _ = try NSRegularExpression(pattern: rule.pattern)
                _ = try rule.negativeGuards.map {
                    try NSRegularExpression(pattern: $0)
                }
            } catch {
                throw RulePackageError.invalidRegex(rule.id)
            }
        }
        for correction in package.corrections {
            guard ["case-diacritic-insensitive-literal", "regular-expression"].contains(correction.matchMode) else {
                throw RulePackageError.invalidMatchMode(correction.matchMode)
            }
            if correction.matchMode == "regular-expression" {
                do {
                    _ = try NSRegularExpression(pattern: correction.match)
                } catch {
                    throw RulePackageError.invalidRegex(correction.id)
                }
            }
        }

        for (index, rule) in parsingRules.enumerated() {
            for other in parsingRules.dropFirst(index + 1)
            where rule.category == other.category &&
                rule.precedence == other.precedence &&
                rule.specificity == other.specificity &&
                rule.pattern == other.pattern {
                throw RulePackageError.precedenceConflict(rule.id, other.id)
            }
        }

        var aliases: [String: String] = [:]
        for alias in package.aliases {
            let key = "\(alias.category):\(SearchNormalizer.normalize(alias.match))"
            if let existing = aliases[key], existing != alias.canonicalValue {
                throw RulePackageError.contradictoryAlias(alias.match)
            }
            aliases[key] = alias.canonicalValue
        }
    }
}
