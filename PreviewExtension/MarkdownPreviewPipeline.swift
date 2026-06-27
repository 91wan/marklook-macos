import Foundation

enum MarkdownPreviewContent: Equatable {
    case webHTML(String)
    case error(title: String, message: String)
}

struct MarkdownPreviewPipeline {
    private let loader: MarkdownPreviewLoader
    private let renderer: MarkdownPreviewRenderer

    init(
        loader: MarkdownPreviewLoader = MarkdownPreviewLoader(),
        renderer: MarkdownPreviewRenderer = MarkdownPreviewRenderer()
    ) {
        self.loader = loader
        self.renderer = renderer
    }

    func preview(for url: URL) -> MarkdownPreviewContent {
        do {
            let document = try loader.loadDocument(from: url)
            let rendered = try renderer.render(document)
            return .webHTML(rendered.html)
        } catch {
            return .error(title: "Preview unavailable", message: error.localizedDescription)
        }
    }
}
