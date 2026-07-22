import SwiftUI

struct FileInformationSection: View {
    let item: CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Filename Title", value: item.source.sourceTitle)
            LabeledContent("Filename", value: item.source.filename)
            LabeledContent("Relative Folder", value: relativeFolder)
            if let notes = item.source.finderComment, !notes.isEmpty {
                LabeledContent("File Notes", value: notes)
            }
            if let width = item.source.pixelWidth, let height = item.source.pixelHeight {
                LabeledContent("Dimensions", value: "\(width) × \(height)")
            }
            if let size = item.source.fileSize {
                LabeledContent("File Size", value: ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
            }
            if let date = item.source.fileCreationDate {
                LabeledContent("Created", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            if let date = item.source.fileModificationDate {
                LabeledContent("Modified", value: date.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent("Cover", value: availabilityLabel)
        }
        .padding(.top, 8)
    }

    private var availabilityLabel: String {
        switch item.availability {
        case .available: L10n.text("Available")
        case .temporarilyUnavailable, .metadataOnly: L10n.text("Temporarily unavailable")
        case .missing: L10n.text("Not found")
        case .ambiguousMatch: L10n.text("Needs review")
        }
    }

    private var relativeFolder: String {
        let folder = (item.source.relativePath as NSString).deletingLastPathComponent
        return folder.isEmpty ? L10n.text("Top level") : folder
    }
}
