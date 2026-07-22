import SwiftUI

struct CatalogConflictReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let pending: PendingCatalogMerge
    let onApply: (Set<UUID>) async -> Bool
    @State private var useExternal: Set<UUID> = []
    @State private var isApplying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Catalog Changes").font(.title2).fontWeight(.semibold)
            Text("The catalog changed outside Vitrine while local changes also existed. Choose a value for each field.")
                .foregroundStyle(.secondary)
            List(pending.conflicts) { conflict in
                VStack(alignment: .leading, spacing: 8) {
                    Text(conflictTitle(conflict))
                        .font(.headline)
                    Picker("Value", selection: choiceBinding(for: conflict.id)) {
                        Text("Keep Mine: \(conflict.localValue)").tag(false)
                        Text("Use Other: \(conflict.externalValue)").tag(true)
                    }
                    .pickerStyle(.radioGroup)
                }
                .padding(.vertical, 6)
            }
            HStack {
                Button("Keep All Mine") { useExternal.removeAll() }
                Button("Use All Other") { useExternal = Set(pending.conflicts.map(\.id)) }
                Spacer()
                Button("Keep Browsing") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isApplying)
                Button("Apply Resolutions", systemImage: "checkmark") {
                    isApplying = true
                    Task {
                        if await onApply(useExternal) { dismiss() }
                        else { isApplying = false }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.glassProminent)
                .disabled(isApplying)
            }
            .buttonStyle(.glass)
        }
        .padding(24)
        .frame(width: 760, height: 680)
        .accessibilityIdentifier("conflict.review")
    }

    private func choiceBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { useExternal.contains(id) },
            set: { value in
                if value { useExternal.insert(id) }
                else { useExternal.remove(id) }
            }
        )
    }

    private func conflictTitle(_ conflict: CatalogMergeConflict) -> String {
        [conflict.bookTitle, conflict.field.label].compactMap { $0 }.joined(separator: " — ")
    }
}
