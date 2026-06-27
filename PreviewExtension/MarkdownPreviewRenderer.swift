import MarkdownCore

enum PreviewRenderDefaults {
    static let options = RenderOptions(
        includeTableOfContents: true,
        fastModeByteThreshold: 1_000_000,
        fastModePreviewByteLimit: 80_000
    )
}

struct MarkdownPreviewRenderer {
    private let renderer: MarkdownRendering
    private let options: RenderOptions

    init(
        renderer: MarkdownRendering = MarkdownRenderer(),
        options: RenderOptions = PreviewRenderDefaults.options
    ) {
        self.renderer = renderer
        self.options = options
    }

    func render(_ document: MarkdownDocument) throws -> RenderResult {
        try renderer.render(document, options: options)
    }
}
