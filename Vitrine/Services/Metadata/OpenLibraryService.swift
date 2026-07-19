import Foundation

actor OpenLibraryService {
    private let session: URLSession
    private let minimumRequestInterval: TimeInterval
    private let retryDelayMilliseconds: Int
    private let maximumAttempts: Int
    private var lastRequestAt = Date.distantPast
    private var cache: [MetadataLookupQuery: [MetadataCandidate]] = [:]

    init(
        session: URLSession = .shared,
        minimumRequestInterval: TimeInterval = 1,
        retryDelayMilliseconds: Int = 350,
        maximumAttempts: Int = 3
    ) {
        self.session = session
        self.minimumRequestInterval = minimumRequestInterval
        self.retryDelayMilliseconds = retryDelayMilliseconds
        self.maximumAttempts = max(1, maximumAttempts)
    }

    func candidates(for query: MetadataLookupQuery, forceRefresh: Bool = false) async throws -> [MetadataCandidate] {
        if !forceRefresh, let cached = cache[query] { return cached }
        let elapsed = Date.now.timeIntervalSince(lastRequestAt)
        if elapsed < minimumRequestInterval { try await Task.sleep(for: .seconds(minimumRequestInterval - elapsed)) }
        let url = try requestURL(query)
        var request = URLRequest(url: url)
        request.setValue("Vitrine/1.0 (macOS private library catalog)", forHTTPHeaderField: "User-Agent")
        var lastError: Error?
        for attempt in 0..<maximumAttempts {
            do {
                lastRequestAt = .now
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                    throw CatalogError.openLibraryUnavailable
                }
                let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                let candidates = decoded.docs.prefix(10).map(candidate)
                guard !candidates.isEmpty else { throw CatalogError.openLibraryNoMatch }
                cache[query] = candidates
                return candidates
            } catch {
                lastError = error
                if attempt < maximumAttempts - 1 {
                    try await Task.sleep(for: .milliseconds(retryDelayMilliseconds * (attempt + 1)))
                }
            }
        }
        throw lastError ?? CatalogError.openLibraryUnavailable
    }

    private func requestURL(_ query: MetadataLookupQuery) throws -> URL {
        var components = URLComponents(string: "https://openlibrary.org/search.json")!
        var items = [URLQueryItem(name: "limit", value: "10")]
        switch query {
        case .isbn(let value): items.append(URLQueryItem(name: "isbn", value: value))
        case .titleAuthor(let title, let author):
            items.append(URLQueryItem(name: "title", value: title))
            if let author, !author.isEmpty { items.append(URLQueryItem(name: "author", value: author)) }
        }
        components.queryItems = items
        guard let url = components.url else { throw CatalogError.openLibraryUnavailable }
        return url
    }

    private func candidate(_ document: SearchDocument) -> MetadataCandidate {
        MetadataCandidate(
            id: document.key ?? UUID().uuidString,
            title: document.title ?? "Untitled",
            subtitle: document.subtitle,
            authors: document.authorName ?? [],
            publisher: document.publisher?.first,
            publicationDate: document.publishDate?.first ?? document.firstPublishYear.map(String.init),
            originalPublicationDate: document.firstPublishYear.map(String.init),
            pageCount: document.numberOfPagesMedian,
            languageCodes: document.language ?? [],
            subjects: Array((document.subject ?? []).prefix(20)),
            isbn10: document.isbn?.first(where: { $0.count == 10 }),
            isbn13: document.isbn?.first(where: { $0.count == 13 }),
            openLibraryWorkID: document.key,
            openLibraryEditionID: document.editionKey?.first
        )
    }

    private struct SearchResponse: Decodable { var docs: [SearchDocument] }
    private struct SearchDocument: Decodable {
        var key: String?
        var title: String?
        var subtitle: String?
        var authorName: [String]?
        var publisher: [String]?
        var publishDate: [String]?
        var firstPublishYear: Int?
        var numberOfPagesMedian: Int?
        var language: [String]?
        var subject: [String]?
        var isbn: [String]?
        var editionKey: [String]?

        enum CodingKeys: String, CodingKey {
            case key, title, subtitle, publisher, language, subject, isbn
            case authorName = "author_name"
            case publishDate = "publish_date"
            case firstPublishYear = "first_publish_year"
            case numberOfPagesMedian = "number_of_pages_median"
            case editionKey = "edition_key"
        }
    }
}
