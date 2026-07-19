import Foundation

actor CatalogScanner {
    private let commentReader = FinderCommentReader()
    private let imageReader = ImageMetadataReader()
    private let fingerprintService = PortableFingerprintService()
    private let reconciler = CatalogReconciler()
    private let folderValidator = SourceFolderValidator()

    private let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "webp",
    ]

    func scan(folderURL: URL) async throws -> CatalogScanResult {
        let canonicalFolderURL = folderURL.resolvingSymlinksInPath().standardizedFileURL
        let enumerationErrors = ScanEnumerationErrorCollector()
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileResourceIdentifierKey
        ]
        guard let enumerator = FileManager.default.enumerator(
            at: canonicalFolderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { url, _ in
                enumerationErrors.append(url: url)
                return true
            }
        ) else {
            throw CatalogError.folderEnumerationFailed
        }

        let enumeratedURLs = enumerator.compactMap { $0 as? URL }
        var files: [SourceFileMetadata] = []
        var warnings = enumerationErrors.warnings
        for fileURL in enumeratedURLs {
            try Task.checkCancellation()
            let values = try fileURL.resourceValues(forKeys: keys)
            guard values.isRegularFile == true,
                  values.isHidden != true,
                  values.isSymbolicLink != true,
                  (values.fileSize ?? 0) > 0 else {
                continue
            }

            let fileExtension = fileURL.pathExtension.lowercased()
            guard supportedExtensions.contains(fileExtension) else { continue }
            let canonicalFileURL = fileURL.resolvingSymlinksInPath().standardizedFileURL
            let relativeComponents = canonicalFileURL.pathComponents.dropFirst(canonicalFolderURL.pathComponents.count)
            guard !relativeComponents.isEmpty else { continue }
            let relativePath = relativeComponents.joined(separator: "/")

            do {
                let dimensions = try await imageReader.dimensions(for: canonicalFileURL)
                let size = Int64(values.fileSize ?? 0)
                let fingerprint = try await fingerprintService.fingerprint(
                    for: canonicalFileURL,
                    fileSize: size,
                    width: dimensions.width,
                    height: dimensions.height
                )
                let comment = await commentReader.comment(for: canonicalFileURL)
                files.append(SourceFileMetadata(
                    relativePath: relativePath,
                    filename: fileURL.lastPathComponent,
                    sourceTitle: fileURL.deletingPathExtension().lastPathComponent,
                    finderComment: comment,
                    portableFingerprint: fingerprint,
                    fileResourceIdentifier: values.fileResourceIdentifier.map { String(describing: $0) },
                    fileSize: size,
                    pixelWidth: dimensions.width,
                    pixelHeight: dimensions.height,
                    fileCreationDate: values.creationDate,
                    fileModificationDate: values.contentModificationDate
                ))
            } catch {
                warnings.append(CatalogScanWarning(
                    relativePath: relativePath,
                    message: L10n.text("One cover could not be read and will be tried again later.")
                ))
            }
        }


        let duplicateFingerprints = Dictionary(grouping: files.indices) { files[$0].portableFingerprint }
            .filter { $0.key != nil && $0.value.count > 1 }
        for indices in duplicateFingerprints.values {
            for index in indices {
                let fileURL = canonicalFolderURL.appending(path: files[index].relativePath)
                do {
                    files[index].fullContentHash = try await fingerprintService.fullFingerprint(for: fileURL)
                } catch {
                    warnings.append(CatalogScanWarning(
                        relativePath: files[index].relativePath,
                        message: L10n.text("One cover changed during identity checking and will be tried again later.")
                    ))
                }
            }
        }

        return CatalogScanResult(
            sources: files.sorted { $0.relativePath < $1.relativePath },
            completedEnumeration: warnings.isEmpty,
            warnings: warnings
        )
    }

    func reconciliationDiff(catalog: CatalogSnapshot, folderURL: URL) async throws -> CatalogReconciliationDiff {
        let scan = try await scan(folderURL: folderURL)
        var diff = await reconciler.diff(catalog: catalog, scan: scan)
        diff.sourceFolderValidated = folderValidator.looksLikeCatalogFolder(
            catalog: catalog,
            sources: scan.sources,
            folderName: folderURL.lastPathComponent
        )
        return diff
    }
}

private final class ScanEnumerationErrorCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CatalogScanWarning] = []

    func append(url: URL) {
        lock.withLock {
            storage.append(CatalogScanWarning(
                relativePath: url.lastPathComponent,
                message: L10n.text("Part of the cover folder could not be read, so no missing books were removed.")
            ))
        }
    }

    var warnings: [CatalogScanWarning] {
        lock.withLock { storage }
    }
}
