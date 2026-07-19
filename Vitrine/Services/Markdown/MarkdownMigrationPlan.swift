import Foundation

struct MarkdownMigrationPlan: Equatable, Sendable {
    var sourceSchema: Int
    var targetSchema: Int
    var requiresBackup: Bool
}
