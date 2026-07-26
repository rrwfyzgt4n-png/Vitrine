import Foundation

enum FilenameParserEngine: Sendable {
    case legacy
    case v2
}

struct FilenameMetadataParser: Sendable {
    private let engine: FilenameParserEngine
    private let configuration: ParsingConfiguration

    init(
        engine: FilenameParserEngine = Self.defaultEngine,
        configuration: ParsingConfiguration = .bundled
    ) {
        self.engine = engine
        self.configuration = configuration
    }

    func suggestions(from sourceTitle: String) -> FilenameMetadataSuggestion {
        switch engine {
        case .legacy:
            LegacyFilenameMetadataParser().suggestions(from: sourceTitle)
        case .v2:
            CitationMetadataParser(configuration: configuration).parse(sourceTitle).suggestion
        }
    }

    func detailedParse(from sourceTitle: String) -> CitationParseResult {
        CitationMetadataParser(configuration: configuration).parse(sourceTitle)
    }

    private static var defaultEngine: FilenameParserEngine {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--filename-parser-v2") {
            return .v2
        }
        if ProcessInfo.processInfo.arguments.contains("--filename-parser-legacy") {
            return .legacy
        }
#endif
        return .legacy
    }
}
