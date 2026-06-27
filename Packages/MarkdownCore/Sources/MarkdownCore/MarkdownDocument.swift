import Foundation

public struct MarkdownDocument: Equatable, Sendable {
    public let source: String
    public let frontMatter: FrontMatter?
    public let sourceByteCount: Int

    public init(source: String, sourceByteCount: Int? = nil) {
        let parsed = FrontMatterParser.parse(source)
        self.source = parsed.body
        self.frontMatter = parsed.frontMatter
        self.sourceByteCount = max(source.utf8.count, sourceByteCount ?? source.utf8.count)
    }
}
