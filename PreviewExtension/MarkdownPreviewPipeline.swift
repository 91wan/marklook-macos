import Foundation

enum MarkdownPreviewContent: Equatable {
    case webHTML(String)
    case error(title: String, message: String)
}

struct MarkdownPreviewPipeline {
    enum Event: Equatable {
        case loadedDocument
        case renderedHTML
    }

    private let loader: MarkdownPreviewLoader
    private let renderer: MarkdownPreviewRenderer

    init(
        loader: MarkdownPreviewLoader = MarkdownPreviewLoader(),
        renderer: MarkdownPreviewRenderer = MarkdownPreviewRenderer()
    ) {
        self.loader = loader
        self.renderer = renderer
    }

    func preview(
        for url: URL,
        onEvent: (Event) -> Void = { _ in }
    ) -> MarkdownPreviewContent {
        do {
            let document = try loader.loadDocument(from: url)
            onEvent(.loadedDocument)
            let rendered = try renderer.render(document)
            onEvent(.renderedHTML)
            return .webHTML(rendered.html)
        } catch {
            return .error(title: "Preview unavailable", message: error.localizedDescription)
        }
    }
}
