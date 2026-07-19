import Foundation

enum CatalogError: LocalizedError, Sendable {
    case catalogUnavailable
    case catalogPermissionDenied
    case catalogMalformed
    case unsupportedSchema(Int)
    case coordinatedReadFailed
    case coordinatedWriteFailed
    case externalConflict
    case sourceFolderUnavailable
    case sourceFolderMismatch
    case folderEnumerationFailed
    case bookmarkResolutionFailed
    case accessPersistenceFailed
    case finderCommentReadFailed(URL)
    case imageMetadataReadFailed(URL)
    case thumbnailGenerationFailed(URL)
    case unstableSourceFile(URL)
    case invalidISBN
    case openLibraryUnavailable
    case openLibraryNoMatch
    case openLibraryMalformedResponse

    var errorDescription: String? {
        switch self {
        case .catalogUnavailable: L10n.text("The catalog is not available.")
        case .catalogPermissionDenied: L10n.text("Vitrine no longer has permission to open this catalog.")
        case .catalogMalformed: L10n.text("The catalog file needs repair.")
        case .unsupportedSchema: L10n.text("This catalog was created by a newer version of Vitrine and is open read-only.")
        case .coordinatedReadFailed: L10n.text("The catalog could not be read safely.")
        case .coordinatedWriteFailed: L10n.text("Your latest changes could not be saved.")
        case .externalConflict: L10n.text("Some changes need your review before the catalog can be updated.")
        case .sourceFolderUnavailable: L10n.text("Covers are unavailable because the folder could not be found.")
        case .sourceFolderMismatch: L10n.text("This folder doesn't seem to match your catalog.")
        case .folderEnumerationFailed: L10n.text("The cover folder could not be refreshed.")
        case .bookmarkResolutionFailed: L10n.text("Vitrine needs permission to access this location again.")
        case .accessPersistenceFailed: L10n.text("Vitrine can use this library now, but could not remember access for the next launch.")
        case .finderCommentReadFailed: L10n.text("One cover's File Notes could not be read.")
        case .imageMetadataReadFailed: L10n.text("One cover's image information could not be read.")
        case .thumbnailGenerationFailed: L10n.text("One cover preview could not be created.")
        case .unstableSourceFile: L10n.text("One cover is still changing and will be tried again later.")
        case .invalidISBN: L10n.text("That ISBN is not valid.")
        case .openLibraryUnavailable: L10n.text("Book details are temporarily unavailable.")
        case .openLibraryNoMatch: L10n.text("No matching book details were found.")
        case .openLibraryMalformedResponse: L10n.text("The book details response could not be read.")
        }
    }
}
