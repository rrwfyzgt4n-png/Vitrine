import Foundation

struct ValidatedISBN: Equatable, Sendable {
    var isbn10: String?
    var isbn13: String
}

enum ISBNValidator {
    static func validate(_ input: String) throws -> ValidatedISBN {
        let normalized = input
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        switch normalized.count {
        case 10 where isValidISBN10(normalized):
            return ValidatedISBN(isbn10: normalized, isbn13: convertISBN10To13(normalized))
        case 13 where isValidISBN13(normalized):
            return ValidatedISBN(isbn10: convertISBN13To10(normalized), isbn13: normalized)
        default:
            throw CatalogError.invalidISBN
        }
    }

    private static func isValidISBN10(_ value: String) -> Bool {
        let characters = Array(value)
        guard characters.count == 10 else { return false }
        var sum = 0
        for (index, character) in characters.enumerated() {
            let digit: Int
            if index == 9, character == "X" {
                digit = 10
            } else if let number = character.wholeNumberValue {
                digit = number
            } else {
                return false
            }
            sum += (10 - index) * digit
        }
        return sum.isMultiple(of: 11)
    }

    private static func isValidISBN13(_ value: String) -> Bool {
        guard value.count == 13, value.allSatisfy(\.isNumber) else { return false }
        let digits = value.compactMap(\.wholeNumberValue)
        let sum = digits.enumerated().reduce(0) { partial, pair in
            partial + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return sum.isMultiple(of: 10)
    }

    private static func convertISBN10To13(_ value: String) -> String {
        let firstNine = value.prefix(9)
        let body = "978" + firstNine
        let digits = body.compactMap(\.wholeNumberValue)
        let sum = digits.enumerated().reduce(0) { partial, pair in
            partial + pair.element * (pair.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return body + String((10 - sum % 10) % 10)
    }

    private static func convertISBN13To10(_ value: String) -> String? {
        guard value.hasPrefix("978") else { return nil }
        let body = String(value.dropFirst(3).dropLast())
        let digits = body.compactMap(\.wholeNumberValue)
        let sum = digits.enumerated().reduce(0) { partial, pair in
            partial + (10 - pair.offset) * pair.element
        }
        let checkValue = (11 - sum % 11) % 11
        return body + (checkValue == 10 ? "X" : String(checkValue))
    }
}
