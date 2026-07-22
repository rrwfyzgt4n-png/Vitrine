import SwiftUI

struct CatalogRecoveryView: View {
    let recovery: CatalogRecoveryCandidate
    let restore: (URL) -> Void
    let openRecovered: () -> Void
    let revealBackup: (URL) -> Void
    let revealDamaged: () -> Void
    let exportDiagnostics: () -> Void
    let createNewCatalog: () -> Void
    let cancel: () -> Void
    @State private var selectedBackupID: URL?

    init(
        recovery: CatalogRecoveryCandidate,
        restore: @escaping (URL) -> Void,
        openRecovered: @escaping () -> Void,
        revealBackup: @escaping (URL) -> Void,
        revealDamaged: @escaping () -> Void,
        exportDiagnostics: @escaping () -> Void,
        createNewCatalog: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) {
        self.recovery = recovery
        self.restore = restore
        self.openRecovered = openRecovered
        self.revealBackup = revealBackup
        self.revealDamaged = revealDamaged
        self.exportDiagnostics = exportDiagnostics
        self.createNewCatalog = createNewCatalog
        self.cancel = cancel
        _selectedBackupID = State(initialValue: recovery.backupOptions.first?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Catalog Repair", systemImage: "cross.case")
                .font(.title2.bold())
            Text(recoveryMessage)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !recovery.backupOptions.isEmpty {
                GroupBox("Choose a Backup") {
                    VStack(spacing: 0) {
                        ForEach(recovery.backupOptions) { option in
                            backupRow(option)
                            if option.id != recovery.backupOptions.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if let recovered = recovery.recoveredCatalog, !recovered.snapshot.items.isEmpty {
                Label(
                    "\(recovered.snapshot.items.count) readable books can be opened without replacing the damaged file.",
                    systemImage: "book.pages"
                )
                .font(.callout)
            }

            HStack {
                Menu("More") {
                    Button("Reveal Damaged File", action: revealDamaged)
                    Button("Export Technical Report…", action: exportDiagnostics)
                    if let selectedBackupID {
                        Button("Show Selected Backup in Finder") { revealBackup(selectedBackupID) }
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel, action: cancel)
                Button("Create New Catalog", action: createNewCatalog)
                if recovery.recoveredCatalog?.snapshot.items.isEmpty == false {
                    Button("Open What Can Be Recovered", action: openRecovered)
                }
                if let selectedBackupID {
                    Button("Repair from Backup") { restore(selectedBackupID) }
                        .buttonStyle(.glassProminent)
                }
            }
            .buttonStyle(.glass)
        }
        .padding(24)
        .frame(width: 660)
        .accessibilityIdentifier("catalog.recovery")
    }

    private func backupRow(_ option: CatalogRecoveryBackupOption) -> some View {
        Button {
            selectedBackupID = option.id
        } label: {
            HStack(spacing: 12) {
                if selectedBackupID == option.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.backup.date.formatted(date: .abbreviated, time: .shortened))
                    Text(L10n.bookCount(option.bookCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(.rect)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityValue(selectedBackupID == option.id ? L10n.text("Selected") : "")
    }

    private var recoveryMessage: LocalizedStringKey {
        recovery.backupOptions.isEmpty
            ? "Vitrine could not safely read this catalog. The damaged source has been preserved; no valid local backup was found."
            : "Vitrine could not safely read this catalog. Choose the backup you want to restore, or open only the records that could be recovered."
    }
}
