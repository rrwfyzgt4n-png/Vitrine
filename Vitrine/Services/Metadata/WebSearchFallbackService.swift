import AppKit
import Foundation

enum WebSearchEngine: String, CaseIterable, Identifiable, Sendable {
    case google
    case duckDuckGo

    var id: Self { self }

    var label: String {
        switch self {
        case .google: "Google"
        case .duckDuckGo: "DuckDuckGo"
        }
    }
}

@MainActor
enum WebSearchFallbackService {
    static func search(_ text: String, using engine: WebSearchEngine) {
        var components = URLComponents()
        components.scheme = "https"
        components.host = engine == .google ? "www.google.com" : "duckduckgo.com"
        components.path = "/"
        components.queryItems = [URLQueryItem(name: "q", value: text)]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }
}
