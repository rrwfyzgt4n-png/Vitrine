import SwiftUI

struct CoverPreviewView: View {
    let item: CatalogItem
    let sourceFolderURL: URL?
    @State private var thumbnail: ThumbnailImage?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.quaternary)
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
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.primary.opacity(0.12), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
            .zIndex(1)

            InspectorCoverShelf()
                .padding(.top, -3)
        }
        .frame(maxWidth: .infinity)
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

private struct InspectorCoverShelf: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(.black.opacity(0.22))
                .frame(width: 238, height: 11)
                .blur(radius: 7)
                .offset(y: 8)

            ShelfTopShape()
                .fill(
                    LinearGradient(
                        colors: [
                            .primary.opacity(reduceTransparency ? 0.18 : 0.14),
                            .primary.opacity(0.035),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 252, height: 10)

            shelfFront
                .frame(width: 260, height: 12)
                .offset(y: 8)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.primary.opacity(0.12))
                        .frame(height: 0.5)
                        .offset(y: 8)
                }
        }
        .frame(width: 270, height: 24)
    }

    @ViewBuilder
    private var shelfFront: some View {
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
        if reduceTransparency {
            shape
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay { shape.stroke(.separator, lineWidth: 0.5) }
        } else {
            shape
                .fill(.thinMaterial)
                .overlay {
                    shape.fill(
                        LinearGradient(
                            colors: [.white.opacity(0.09), .black.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
        }
    }
}

private struct ShelfTopShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 8, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
