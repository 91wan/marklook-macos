import CoreGraphics
import Foundation
import OSLog
import Quartz
import UniformTypeIdentifiers

final class PreviewViewController: QLPreviewProvider, QLPreviewingController {
    private static let previewSize = CGSize(width: 1000, height: 800)

    private let pipeline = MarkdownPreviewPipeline()

    func providePreview(
        for request: QLFilePreviewRequest,
        completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void
    ) {
        let url = request.fileURL
        let fileName = url.lastPathComponent
        AppLog.preview.info("providePreview start file=\(fileName, privacy: .public)")

        let preview = pipeline.preview(for: url) { event in
            switch event {
            case .loadedDocument:
                AppLog.preview.info("load document success file=\(fileName, privacy: .public)")
            case .renderedHTML:
                AppLog.preview.info("render success file=\(fileName, privacy: .public)")
            }
        }

        let html: String
        switch preview {
        case let .htmlDocument(document):
            html = document
            AppLog.preview.info("html document ready file=\(fileName, privacy: .public) htmlBytes=\(document.utf8.count, privacy: .public)")
        case let .error(title, message):
            html = PreviewErrorHTMLDocument.html(
                title: title,
                message: message
            )
            AppLog.preview.error("error html ready file=\(fileName, privacy: .public) title=\(title, privacy: .public)")
        }

        let reply = QLPreviewReply(
            dataOfContentType: .html,
            contentSize: Self.previewSize
        ) { reply in
            reply.stringEncoding = .utf8
            reply.title = fileName
            return Data(html.utf8)
        }

        handler(reply, nil)
    }
}
