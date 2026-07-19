import SwiftUI

struct BookCardView: View {
    let item: CatalogItem
    let isSelected: Bool
    let sourceFolderURL: URL?
    let coverWidth: Double
    let showFileNoteSummary: Bool
    @State private var thumbnail: ThumbnailImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.quaternary)
                if let thumbnail {
                    Image(decorative: thumbnail.cgImage, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "book.closed")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(.tint, lineWidth: 3)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .tint)
                        .padding(7)
                        .accessibilityHidden(true)
                }
            }
            .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
            .accessibilityHidden(true)

            Text(item.displayTitle)
                .font(.headline)
                .lineLimit(2)
            if let author = item.displayAuthor ?? fileNoteSummary,
               !author.isEmpty {
                Text(author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isSelected ? L10n.text("Selected") : "")
        .task(id: thumbnailRequestID) {
            thumbnail = nil
            guard item.availability == .available, let sourceFolderURL else { return }
            thumbnail = try? await ThumbnailService.shared.thumbnail(
                sourceFolderURL: sourceFolderURL,
                source: item.source,
                maximumPixelSize: Int(coverWidth * 2)
            )
        }
    }

    private var accessibilityLabel: String {
        [
            item.displayTitle,
            item.displayAuthor,
            item.availability == .available ? L10n.text("cover available") : L10n.text("cover unavailable")
        ]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    private var fileNoteSummary: String? {
        guard showFileNoteSummary else { return nil }
        return item.source.finderComment?.components(separatedBy: .newlines).first
    }

    private var thumbnailRequestID: String {
        [
            sourceFolderURL?.path(percentEncoded: false) ?? "unavailable",
            item.source.relativePath,
            item.source.fileSize.map(String.init) ?? "",
            item.source.fileModificationDate.map { String($0.timeIntervalSince1970) } ?? "",
            String(Int(coverWidth))
        ].joined(separator: "|")
    }
}
