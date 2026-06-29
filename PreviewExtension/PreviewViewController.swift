import Cocoa
import OSLog
import Quartz

final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private let pipeline = MarkdownPreviewPipeline()

    override func loadView() {
        AppLog.preview.info("loadView")
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let fileName = url.lastPathComponent
        AppLog.preview.info("preparePreviewOfFile start file=\(fileName, privacy: .public)")

        let preview = pipeline.preview(for: url) { event in
            switch event {
            case .loadedDocument:
                AppLog.preview.info("load document success file=\(fileName, privacy: .public)")
            case .renderedHTML:
                AppLog.preview.info("render success file=\(fileName, privacy: .public)")
            }
        }

        switch preview {
        case let .webHTML(html):
            view = MarkdownPreviewWebView(html: html)
            AppLog.preview.info("web view assigned file=\(fileName, privacy: .public) htmlBytes=\(html.utf8.count, privacy: .public)")
            handler(nil)
        case let .error(title, message):
            view = PreviewErrorView(
                title: title,
                message: message
            )
            AppLog.preview.error("error view assigned file=\(fileName, privacy: .public) title=\(title, privacy: .public)")
            // Return nil after installing PreviewErrorView so Quick Look displays the local error UI
            // instead of falling back to another provider or showing a blank panel.
            handler(nil)
        }
    }
}
