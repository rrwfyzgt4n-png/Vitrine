import Foundation

enum MarkdownEscaping {
    static func inlineCode(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    static func unescapeInlineCode(_ value: String) -> String {
        var result = ""
        var isEscaped = false
        for character in value {
            if isEscaped {
                result.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }
        if isEscaped { result.append("\\") }
        return result
    }

    static func heading(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "#", with: "\\#")
    }

    static func yamlScalar(_ value: String) -> String {
        let requiresQuotes = value.isEmpty || value.contains(where: { ":#\"\\\n\r".contains($0) })
        guard requiresQuotes else { return value }
        return "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n") + "\""
    }

    static func unescapeYAMLScalar(_ value: String) -> String {
        guard value.first == "\"", value.last == "\"", value.count >= 2 else { return value }
        let body = value.dropFirst().dropLast()
        var result = ""
        var isEscaped = false
        for character in body {
            if isEscaped {
                result.append(character == "n" ? "\n" : character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }
        if isEscaped { result.append("\\") }
        return result
    }
}
