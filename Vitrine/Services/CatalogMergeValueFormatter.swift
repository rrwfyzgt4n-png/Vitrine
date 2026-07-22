import Foundation

struct CatalogMergeValueFormatter: Sendable {
    func string<Value>(for value: Value) -> String {
        guard let unwrapped = unwrapOptional(value) else { return L10n.text("Not set") }

        if let value = unwrapped as? String { return value.isEmpty ? L10n.text("Empty") : value }
        if let value = unwrapped as? [String] { return value.isEmpty ? L10n.text("Empty") : value.joined(separator: ", ") }
        if let value = unwrapped as? [BibliographicContributor] {
            return BibliographicDisplayFormatter.contributors(value) ?? L10n.text("Empty")
        }
        if let value = unwrapped as? [PhysicalAttribute] {
            return BibliographicDisplayFormatter.physicalAttributes(value) ?? L10n.text("Empty")
        }
        if let value = unwrapped as? PaginationStatus { return value.label }
        if let value = unwrapped as? Date { return CatalogDateFormatter.string(from: value) }
        if let value = unwrapped as? MetadataSource { return value.label }
        if let value = unwrapped as? ItemAvailability { return value.inspectorLabel }
        if let value = unwrapped as? SourceFileMetadata { return value.relativePath }
        if let value = unwrapped as? CatalogItem { return value.displayTitle }
        if let value = unwrapped as? Bool { return value ? L10n.text("Yes") : L10n.text("No") }
        if let value = unwrapped as? Int { return String(value) }
        if let value = unwrapped as? Int64 { return String(value) }
        return L10n.text("Unavailable")
    }

    private func unwrapOptional(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }
}
