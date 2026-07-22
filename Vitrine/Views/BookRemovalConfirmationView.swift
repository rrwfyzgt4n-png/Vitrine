import SwiftUI

struct BookRemovalConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    let item: CatalogItem
    let sourceFolderURL: URL?
    let cancel: () -> Void
    let remove: () async -> Bool
    @State private var thumbnail: ThumbnailImage?
    @State private var isRemoving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Remove Book from Catalog?", systemImage: "exclamationmark.triangle")
                .font(.title2.bold())

            HStack(alignment: .top, spacing: 20) {
                coverPreview
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.displayTitle)
                        .font(.title3.bold())
                        .lineLimit(4)
                    if let author = item.displayAuthor {
                        Text(author)
                            .foregroundStyle(.secondary)
                    }
                    Text("The cover image will remain in its folder. Only this catalog record and its saved book details will be removed.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isRemoving)
                Button("Remove from Catalog", role: .destructive) {
                    isRemoving = true
                    Task {
                        if await remove() { dismiss() }
                        else { isRemoving = false }
                    }
                }
                .disabled(isRemoving)
            }
        }
        .padding(24)
        .frame(width: 560)
        .task(id: item.id) {
            guard let sourceFolderURL else { return }
            thumbnail = try? await ThumbnailService.shared.thumbnail(
                sourceFolderURL: sourceFolderURL,
                source: item.source,
                maximumPixelSize: 360
            )
        }
    }

    private var coverPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary)
            if let thumbnail {
                Image(decorative: thumbnail.cgImage, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 130, height: 190)
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
        .accessibilityHidden(true)
    }
}
