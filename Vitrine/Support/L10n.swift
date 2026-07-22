import Foundation

enum L10n {
    static func text(_ value: String.LocalizationValue) -> String {
        String(localized: value)
    }

    static func bookCount(_ count: Int) -> String {
        String(localized: "\(count) books")
    }
}
