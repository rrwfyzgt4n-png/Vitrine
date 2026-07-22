import Foundation

struct CatalogDiagnosticService: Sendable {
    func report(
        catalog: CatalogSnapshot,
        health: CatalogHealthReport,
        diagnostics: [MarkdownDiagnostic],
        scanWarnings: [CatalogScanWarning]
    ) -> String {
        let availabilityCounts = Dictionary(grouping: catalog.items, by: \.availability)
            .mapValues(\.count)
        let diagnosticCounts = Dictionary(grouping: diagnostics, by: { $0.code.rawValue })
            .mapValues(\.count)

        var lines = [
            "Vitrine Privacy-Safe Diagnostic Report",
            "Generated: \(CatalogDateFormatter.string(from: .now))",
            "Application version: \(applicationVersion)",
            "Operating system: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Catalog open read-only: \(catalog.isReadOnly ? "yes" : "no")",
            "Readable records: \(health.readableRecordCount)",
            "Unavailable covers: \(health.unavailableCoverCount)",
            "Duplicate records: \(health.duplicateRecordCount)",
            "Damaged records: \(health.damagedRecordCount)",
            "Parser warnings: \(health.warningCount)",
            "Scan warnings: \(scanWarnings.count)",
            "Local backups: \(health.backupCount)",
            "",
            "Availability counts",
        ]
        for availability in ItemAvailability.allCases {
            lines.append("- \(availability.rawValue): \(availabilityCounts[availability, default: 0])")
        }
        lines.append("")
        lines.append("Parser diagnostic codes")
        if diagnosticCounts.isEmpty {
            lines.append("- none")
        } else {
            for code in diagnosticCounts.keys.sorted() {
                lines.append("- \(code): \(diagnosticCounts[code, default: 0])")
            }
        }
        lines.append("")
        lines.append("This report intentionally excludes catalog identifiers, file paths, book titles, authors, notes, cover contents, fingerprints, and checksums.")
        return lines.joined(separator: "\n") + "\n"
    }

    private var applicationVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(version) (\(build))"
    }
}
