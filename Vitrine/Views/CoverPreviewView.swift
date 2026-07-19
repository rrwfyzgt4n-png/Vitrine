import SwiftUI

struct CoverPreviewView: View {
    let item: CatalogItem
    let sourceFolderURL: URL?
    @State private var thumbnail: ThumbnailImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.quaternary)
            if let thumbnail {
                Image(decorative: thumbnail.cgImage, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .frame(maxWidth: 220)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
        .task(id: thumbnailRequestID) {
            thumbnail = nil
            guard item.availability == .available, let sourceFolderURL else { return }
            thumbnail = try? await ThumbnailService.shared.thumbnail(
                sourceFolderURL: sourceFolderURL,
                source: item.source,
                maximumPixelSize: 640
            )
        }
    }

    private var thumbnailRequestID: String {
        [
            sourceFolderURL?.path(percentEncoded: false) ?? "unavailable",
            item.source.relativePath,
            item.source.fileSize.map(String.init) ?? "",
            item.source.fileModificationDate.map { String($0.timeIntervalSince1970) } ?? ""
        ].joined(separator: "|")
    }
}
