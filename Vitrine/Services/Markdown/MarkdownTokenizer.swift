import Foundation

enum MarkdownTokenizer {
    static let itemBeginPrefix = "<!-- library-catalog:item:begin id=\""
    static let itemBeginSuffix = "\" -->"
    static let itemEnd = "<!-- library-catalog:item:end -->"

    static func normalizedLines(in source: String) -> [String] {
        source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    static func recordID(from line: String) -> UUID? {
        guard line.hasPrefix(itemBeginPrefix), line.hasSuffix(itemBeginSuffix) else { return nil }
        let start = line.index(line.startIndex, offsetBy: itemBeginPrefix.count)
        let end = line.index(line.endIndex, offsetBy: -itemBeginSuffix.count)
        return UUID(uuidString: String(line[start..<end]))
    }

    static func field(from line: String) -> (key: String, value: String)? {
        guard line.hasPrefix("- "), let separator = line.firstIndex(of: ":") else { return nil }
        let keyStart = line.index(line.startIndex, offsetBy: 2)
        let key = String(line[keyStart..<separator])
        var value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        if value.first == "`", value.last == "`", value.count >= 2 {
            value = String(value.dropFirst().dropLast())
            value = MarkdownEscaping.unescapeInlineCode(value)
        }
        return (key, value)
    }
}
