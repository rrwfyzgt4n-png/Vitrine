import SwiftUI

struct CatalogRecoveryView: View {
    let recovery: CatalogRecoveryCandidate
    let restore: () -> Void
    let revealBackup: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Catalog Repair", systemImage: "cross.case")
                .font(.title2.bold())
            Text("Vitrine could not read this catalog. The damaged file has been preserved, and a valid local backup is available. Nothing will be replaced until you choose Restore Backup.")
                .fixedSize(horizontal: false, vertical: true)
            GroupBox("Available Backup") {
                LabeledContent("Date", value: recovery.backup.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Books", value: L10n.bookCount(recovery.parsedBackup.snapshot.items.count))
            }
            HStack {
                Button("Show Backup in Finder", action: revealBackup)
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                Button("Restore Backup", action: restore)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}
