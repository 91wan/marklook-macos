import Cocoa
import Quartz

final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private let pipeline = MarkdownPreviewPipeline()

    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        switch pipeline.preview(for: url) {
        case let .webHTML(html):
            view = MarkdownPreviewWebView(html: html)
            handler(nil)
        case let .error(title, message):
            view = PreviewErrorView(
                title: title,
                message: message
            )
            // Return nil after installing PreviewErrorView so Quick Look displays the local error UI
            // instead of falling back to another provider or showing a blank panel.
            handler(nil)
        }
    }
}
