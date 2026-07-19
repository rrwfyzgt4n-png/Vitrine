import Foundation

struct MarkdownDiagnostic: Equatable, Sendable {
    enum Severity: String, Sendable {
        case warning
        case error
    }

    enum Code: String, Sendable {
        case missingFrontMatter
        case invalidFrontMatter
        case unsupportedSchema
        case invalidCatalogID
        case invalidDate
        case invalidRecordMarker
        case overlappingRecord
        case unclosedRecord
        case invalidRecordID
        case duplicateRecordID
        case missingRequiredField
        case invalidFieldValue
        case recordCountMismatch
    }

    var severity: Severity
    var code: Code
    var line: Int?
    var recordID: UUID?
    var message: String
}

struct CatalogParseResult: Equatable, Sendable {
    var snapshot: CatalogSnapshot
    var diagnostics: [MarkdownDiagnostic]

    var hasUnrecoverableErrors: Bool {
        diagnostics.contains { diagnostic in
            diagnostic.severity == .error && diagnostic.recordID == nil
        }
    }
}
