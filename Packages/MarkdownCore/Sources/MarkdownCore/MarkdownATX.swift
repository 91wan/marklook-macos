import Foundation

enum MarkdownATX {
    static func parse(_ line: String) -> (level: Int, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        var cursor = trimmed.startIndex

        while cursor < trimmed.endIndex, trimmed[cursor] == "#", level < 6 {
            level += 1
            cursor = trimmed.index(after: cursor)
        }

        guard level > 0, cursor < trimmed.endIndex, trimmed[cursor] == " " else {
            return nil
        }

        let title = String(trimmed[trimmed.index(after: cursor)...]).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else {
            return nil
        }

        return (level, title)
    }
}
