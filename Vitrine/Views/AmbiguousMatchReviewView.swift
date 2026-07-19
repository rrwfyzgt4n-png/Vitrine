import SwiftUI

struct AmbiguousMatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let item: CatalogItem
    let candidates: [FileCandidate]
    let onChoose: (String) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose the Matching Cover").font(.title2).fontWeight(.semibold)
            Text("Several files have the same portable identity as \(item.displayTitle). Vitrine will not guess.")
                .foregroundStyle(.secondary)
            List(candidates, id: \.relativePath) { candidate in
                HStack {
                    Image(systemName: "photo")
                    Text(candidate.relativePath).textSelection(.enabled)
                    Spacer()
                    Button("Use This Cover") { Task { await onChoose(candidate.relativePath); dismiss() } }
                }
                .padding(.vertical, 5)
            }
            HStack {
                Spacer()
                Button("Review Later") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 660, height: 480)
    }
}
