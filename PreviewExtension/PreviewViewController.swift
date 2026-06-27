import Cocoa
import Quartz

final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private let loader = MarkdownPreviewLoader()
    private let renderer = MarkdownPreviewRenderer()

    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let document = try loader.loadDocument(from: url)
            let rendered = try renderer.render(document)
            view = MarkdownPreviewWebView(html: rendered.html)
            handler(nil)
        } catch {
            view = PreviewErrorView(
                title: "Preview unavailable",
                message: error.localizedDescription
            )
            handler(nil)
        }
    }
}
