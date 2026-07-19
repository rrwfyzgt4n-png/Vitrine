import SwiftUI

struct FileInformationSection: View {
    let item: CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Filename Title", value: item.source.sourceTitle)
            LabeledContent("Filename", value: item.source.filename)
            LabeledContent("Relative Folder", value: (item.source.relativePath as NSString).deletingLastPathComponent.isEmpty ? "Top level" : (item.source.relativePath as NSString).deletingLastPathComponent)
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
        case .available: "Available"
        case .temporarilyUnavailable, .metadataOnly: "Temporarily unavailable"
        case .missing: "Not found"
        case .ambiguousMatch: "Needs review"
        }
    }
}
