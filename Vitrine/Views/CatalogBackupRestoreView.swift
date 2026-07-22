import SwiftUI

struct CatalogBackupRestoreView: View {
    @Environment(\.dismiss) private var dismiss
    let options: [CatalogRecoveryBackupOption]
    let restore: (URL) async -> Bool
    @State private var selection: URL?
    @State private var isRestoring = false

    init(options: [CatalogRecoveryBackupOption], restore: @escaping (URL) async -> Bool) {
        self.options = options
        self.restore = restore
        _selection = State(initialValue: options.first?.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Restore Previous Catalog Version", systemImage: "clock.arrow.circlepath")
                .font(.title2.bold())
            Text("Choose a dated local backup. Vitrine will preserve the current catalog before restoring it.")
                .foregroundStyle(.secondary)

            List(options, selection: $selection) { option in
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.backup.date.formatted(date: .abbreviated, time: .shortened))
                    Text(L10n.bookCount(option.bookCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(option.id)
                .padding(.vertical, 4)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isRestoring)
                Button("Restore Selected Backup") {
                    guard let selection else { return }
                    isRestoring = true
                    Task {
                        if await restore(selection) { dismiss() }
                        else { isRestoring = false }
                    }
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil || isRestoring)
            }
            .buttonStyle(.glass)
        }
        .padding(24)
        .frame(width: 560, height: 460)
    }
}
