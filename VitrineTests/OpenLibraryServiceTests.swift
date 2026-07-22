import Foundation
import XCTest
@testable import Vitrine

final class OpenLibraryServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testTitleAuthorSearchDecodesPartialCandidateWithoutMutation() async throws {
        URLProtocolStub.handler = { request in
            let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "title" })?.value, "The Trial")
            XCTAssertEqual(components.queryItems?.first(where: { $0.name == "author" })?.value, "Franz Kafka")
            let data = Data(#"{"docs":[{"key":"/works/OL1W","title":"The Trial","author_name":["Franz Kafka"],"first_publish_year":1925}]}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let service = OpenLibraryService(
            session: stubSession(), minimumRequestInterval: 0, retryDelayMilliseconds: 0, maximumAttempts: 1
        )

        let candidates = try await service.candidates(for: .titleAuthor(title: "The Trial", author: "Franz Kafka"))

        XCTAssertEqual(candidates.first?.title, "The Trial")
        XCTAssertEqual(candidates.first?.originalPublicationDate, "1925")
    }

    func testMalformedResponseIsBoundedAndFailsSafely() async {
        URLProtocolStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data("{".utf8))
        }
        let service = OpenLibraryService(
            session: stubSession(), minimumRequestInterval: 0, retryDelayMilliseconds: 0, maximumAttempts: 1
        )

        do {
            _ = try await service.candidates(for: .isbn("9780141187761"))
            XCTFail("Expected malformed response to fail")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testRepeatedLookupUsesMemoryCacheWithoutAnotherRequest() async throws {
        let requestCounter = RequestCounter()
        URLProtocolStub.handler = { request in
            requestCounter.increment()
            let data = Data(#"{"docs":[{"key":"/works/OL2W","title":"Cached Book"}]}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let service = OpenLibraryService(
            session: stubSession(), minimumRequestInterval: 0, retryDelayMilliseconds: 0, maximumAttempts: 1
        )
        let query = MetadataLookupQuery.titleAuthor(title: "Cached Book", author: nil)

        let first = try await service.candidates(for: query)
        let second = try await service.candidates(for: query)

        XCTAssertEqual(first, second)
        XCTAssertEqual(requestCounter.value, 1)
    }

    private func stubSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.withLock { count }
    }

    func increment() {
        lock.withLock { count += 1 }
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
