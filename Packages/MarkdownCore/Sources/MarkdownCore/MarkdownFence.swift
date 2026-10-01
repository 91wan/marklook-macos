import Foundation

struct MarkdownFence {
    let marker: Character
    let count: Int
    let info: String

    static func parse(_ line: String) -> MarkdownFence? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let marker = trimmed.first, marker == "`" || marker == "~" else {
            return nil
        }

        let count = trimmed.prefix { $0 == marker }.count
        guard count >= 3 else {
            return nil
        }

        let info = String(trimmed.dropFirst(count)).trimmingCharacters(in: .whitespaces)
        return MarkdownFence(marker: marker, count: count, info: info)
    }

    func closes(_ opening: MarkdownFence) -> Bool {
        marker == opening.marker
            && count >= opening.count
            && info.isEmpty
    }
}
