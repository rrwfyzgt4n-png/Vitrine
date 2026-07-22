import Foundation

struct CoverPathResolver: Sendable {
    func resolve(relativePath: String, inside sourceFolderURL: URL) throws -> URL {
        guard !relativePath.isEmpty,
              !relativePath.contains("\\"),
              !relativePath.contains("\0"),
              !NSString(string: relativePath).isAbsolutePath else {
            throw CatalogError.invalidCoverPath
        }

        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw CatalogError.invalidCoverPath
        }

        let root = sourceFolderURL.resolvingSymlinksInPath().standardizedFileURL
        let rootComponents = root.pathComponents
        var candidate = root
        for component in components {
            candidate = candidate
                .appending(path: String(component))
                .resolvingSymlinksInPath()
                .standardizedFileURL
            guard candidate.pathComponents.count > rootComponents.count,
                  candidate.pathComponents.starts(with: rootComponents) else {
                throw CatalogError.invalidCoverPath
            }
        }
        return candidate
    }
}
