import Foundation

public enum TableOfContents {
    public struct Item: Equatable, Sendable {
        public let title: String
        public let level: Int
        public let id: String

        public init(title: String, level: Int, id: String) {
            self.title = title
            self.level = level
            self.id = id
        }
    }

    public static func slug(for title: String) -> String {
        var slug = ""
        var previousWasSeparator = false

        for scalar in title.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                slug.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !slug.isEmpty, !previousWasSeparator {
                slug.append("-")
                previousWasSeparator = true
            }
        }

        while slug.last == "-" {
            slug.removeLast()
        }

        return slug.isEmpty ? "section" : slug
    }

    static func uniqueSlug(for title: String, counts: inout [String: Int]) -> String {
        let base = slug(for: title)
        let nextCount = (counts[base] ?? 0) + 1
        counts[base] = nextCount

        return nextCount == 1 ? base : "\(base)-\(nextCount)"
    }
}
