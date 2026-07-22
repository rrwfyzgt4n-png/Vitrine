import SwiftUI

struct CatalogHealthReportView: View {
    @Environment(\.dismiss) private var dismiss
    let report: CatalogHealthReport

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(
                report.isHealthy ? "Your catalog is healthy." : "Your catalog needs minor repairs.",
                systemImage: report.isHealthy ? "checkmark.circle" : "wrench.and.screwdriver"
            )
            .font(.title2.bold())

            if !report.isHealthy {
                Text("Most of the catalog can still be used.")
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
                healthRow("Readable records", value: report.readableRecordCount)
                healthRow("Unavailable covers", value: report.unavailableCoverCount)
                healthRow("Duplicate records", value: report.duplicateRecordCount)
                healthRow("Records that could not be read", value: report.damagedRecordCount)
                healthRow("Parser warnings", value: report.warningCount)
                healthRow("Available local backups", value: report.backupCount)
                if let latestBackupDate = report.latestBackupDate {
                    GridRow {
                        Text("Latest backup").foregroundStyle(.secondary)
                        Text(latestBackupDate.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }

            Text("Technical details are available only through Export Diagnostic Report.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540)
    }

    private func healthRow(_ label: LocalizedStringKey, value: Int) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value, format: .number)
        }
    }
}
