import MarkdownCore

struct MarkdownPreviewRenderer {
    private let renderer: MarkdownRendering
    private let options: RenderOptions

    init(
        renderer: MarkdownRendering = MarkdownRenderer(),
        options: RenderOptions = RenderOptions(
            includeTableOfContents: true,
            fastModeByteThreshold: 1_000_000,
            fastModePreviewByteLimit: 80_000
        )
    ) {
        self.renderer = renderer
        self.options = options
    }

    func render(_ document: MarkdownDocument) throws -> RenderResult {
        try renderer.render(document, options: options)
    }
}
