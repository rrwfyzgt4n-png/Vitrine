import SwiftUI

struct BookCardView: View {
    let item: CatalogItem
    let isSelected: Bool
    let sourceFolderURL: URL?
    let coverWidth: Double
    let showFileNoteSummary: Bool
    let gridPosition: Int
    let gridCount: Int
    let hasKeyboardFocus: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var thumbnail: ThumbnailImage?
    @State private var isHovering = false

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
                        .stroke(
                            colorSchemeContrast == .increased ? Color.primary : Color.accentColor,
                            style: StrokeStyle(
                                lineWidth: colorSchemeContrast == .increased ? 5 : 3,
                                dash: differentiateWithoutColor ? [7, 3] : []
                            )
                        )
                }
            }
            .overlay {
                if isSelected && hasKeyboardFocus {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary, lineWidth: colorSchemeContrast == .increased ? 2 : 1)
                        .padding(-4)
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
            .shadow(
                color: .black.opacity(isHovering ? 0.23 : 0.16),
                radius: isHovering ? 7 : 4,
                y: isHovering ? 4 : 2
            )
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
        .scaleEffect(isHovering && !reduceMotion ? 1.015 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("book.\(item.id.uuidString)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .task(id: thumbnailRequestID) {
            guard item.availability == .available, let sourceFolderURL else {
                thumbnail = nil
                return
            }
            let updatedThumbnail = try? await ThumbnailService.shared.thumbnail(
                sourceFolderURL: sourceFolderURL,
                source: item.source,
                maximumPixelSize: Int(coverWidth * 2)
            )
            guard !Task.isCancelled, let updatedThumbnail else { return }
            thumbnail = updatedThumbnail
        }
    }

    private var accessibilityLabel: String {
        var values = [
            item.displayTitle,
            item.displayAuthor,
            availabilityLabel,
        ]
        if item.bibliography.metadataSource != nil {
            values.append(L10n.text("book details added"))
        }
        if let isbn = item.bibliography.isbn13 ?? item.bibliography.isbn10 {
            values.append(String(localized: "ISBN \(isbn)"))
        }
        values.append(String(localized: "Book \(gridPosition) of \(gridCount)"))
        return values.compactMap { $0 }.joined(separator: ", ")
    }

    private var accessibilityValue: String {
        let position = String(localized: "Book \(gridPosition) of \(gridCount)")
        return isSelected ? "\(L10n.text("Selected")), \(position)" : position
    }

    private var availabilityLabel: String {
        switch item.availability {
        case .available: L10n.text("cover available")
        case .temporarilyUnavailable: L10n.text("cover temporarily unavailable")
        case .missing: L10n.text("cover not found")
        case .ambiguousMatch: L10n.text("cover needs review")
        case .metadataOnly: L10n.text("browsing without cover folder")
        }
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
