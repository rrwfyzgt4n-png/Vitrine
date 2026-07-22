import Foundation

enum BibliographicDisplayFormatter {
    static func contributors(_ contributors: [BibliographicContributor]) -> String? {
        guard !contributors.isEmpty else { return nil }
        return contributors.map { contributor in
            let roles = contributor.roles.map(\.label).joined(separator: ", ")
            return roles.isEmpty ? contributor.name : "\(contributor.name) (\(roles))"
        }.joined(separator: "; ")
    }

    static func physicalAttributes(_ attributes: [PhysicalAttribute]) -> String? {
        guard !attributes.isEmpty else { return nil }
        return attributes.map(\.label).joined(separator: ", ")
    }
}
