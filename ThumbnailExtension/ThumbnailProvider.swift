import AppKit
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let size = request.maximumSize
        let metadata: MarkdownThumbnailMetadata
        do {
            metadata = try MarkdownThumbnailMetadata.load(from: request.fileURL)
        } catch {
            metadata = MarkdownThumbnailMetadata(
                fileName: request.fileURL.lastPathComponent,
                fileExtension: request.fileURL.pathExtension,
                heading: nil,
                approximateLineCount: 0,
                isTruncated: false,
                isUTF8: false
            )
        }

        let reply = QLThumbnailReply(contextSize: size) {
            MarkdownThumbnailRenderer.draw(
                metadata: metadata,
                size: size,
                appearance: NSAppearance.current
            )
            return true
        }

        handler(reply, nil)
    }
}
