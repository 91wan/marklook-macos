import Foundation

public struct FrontMatter: Equatable, Sendable {
    public let fields: [String: String]

    public init(fields: [String: String]) {
        self.fields = fields
    }
}

enum FrontMatterParser {
    static func parse(_ source: String) -> (frontMatter: FrontMatter?, body: String) {
        guard source.hasPrefix("---\n") || source.hasPrefix("---\r\n") else {
            return (nil, source)
        }

        let firstLineEnd = source.firstIndex(of: "\n")!
        var cursor = source.index(after: firstLineEnd)

        while cursor < source.endIndex {
            let lineStart = cursor
            let lineEnd = source[cursor...].firstIndex(of: "\n") ?? source.endIndex
            let line = String(source[lineStart..<lineEnd]).trimmingCharacters(in: CharacterSet(charactersIn: "\r"))

            if line == "---" {
                let metadata = String(source[source.index(after: firstLineEnd)..<lineStart])
                let bodyStart = lineEnd == source.endIndex ? source.endIndex : source.index(after: lineEnd)
                return (FrontMatter(fields: parseFields(metadata)), String(source[bodyStart...]))
            }

            cursor = lineEnd == source.endIndex ? source.endIndex : source.index(after: lineEnd)
        }

        return (nil, source)
    }

    private static func parseFields(_ metadata: String) -> [String: String] {
        var fields: [String: String] = [:]

        for rawLine in metadata.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let separator = line.firstIndex(of: ":") else {
                continue
            }

            let key = String(line[..<separator]).trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            if value.count >= 2,
               let first = value.first,
               let last = value.last,
               (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                value.removeFirst()
                value.removeLast()
            }

            if !key.isEmpty {
                fields[key] = value
            }
        }

        return fields
    }
}
