import Foundation

public struct MarkdownDocument: Equatable, Sendable {
    public let source: String
    public let frontMatter: FrontMatter?
    public let sourceByteCount: Int

    public init(source: String, sourceByteCount: Int? = nil) {
        let normalizedSource = source.first == "\u{FEFF}"
            ? String(source.dropFirst())
            : source
        let parsed = FrontMatterParser.parse(normalizedSource)
        self.source = parsed.body
        self.frontMatter = parsed.frontMatter
        self.sourceByteCount = max(source.utf8.count, sourceByteCount ?? source.utf8.count)
    }
}
