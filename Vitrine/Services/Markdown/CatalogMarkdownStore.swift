import Foundation

actor CatalogMarkdownStore {
    private let parser = CatalogMarkdownParser()

    func read(from url: URL) async throws -> CatalogParseResult {
        let parser = self.parser
        return try await Task.detached(priority: .userInitiated) {
            var coordinationError: NSError?
            var result: Result<CatalogParseResult, Error>?
            let coordinator = NSFileCoordinator(filePresenter: nil)

            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
                do {
                    let data = try Data(contentsOf: coordinatedURL, options: [.mappedIfSafe])
                    guard let source = String(data: data, encoding: .utf8) else {
                        throw CatalogError.catalogMalformed
                    }
                    result = Result { try parser.parse(source) }
                } catch {
                    result = .failure(error)
                }
            }

            if let coordinationError { throw coordinationError }
            guard let result else { throw CatalogError.coordinatedReadFailed }
            return try result.get()
        }.value
    }
}
