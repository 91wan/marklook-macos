import AppKit
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let size = request.maximumSize
        let scale = request.scale
        let fileName = request.fileURL.lastPathComponent
        AppLog.thumbnail.info("provideThumbnail start file=\(fileName, privacy: .private) maxSize=\(Int(size.width))x\(Int(size.height)) scale=\(scale)")

        let metadata: MarkdownThumbnailMetadata
        do {
            metadata = try MarkdownThumbnailMetadata.load(from: request.fileURL)
            let headingState = metadata.heading == nil ? "no" : "yes"
            let truncatedState = metadata.isTruncated ? "yes" : "no"
            let utf8State = metadata.isUTF8 ? "yes" : "no"
            AppLog.thumbnail.info("metadata loaded file=\(fileName, privacy: .private) heading=\(headingState, privacy: .public) lines=\(metadata.approximateLineCount) truncated=\(truncatedState, privacy: .public) utf8=\(utf8State, privacy: .public)")
        } catch {
            AppLog.thumbnail.error("metadata fallback file=\(fileName, privacy: .private) error=<redacted>")
            metadata = MarkdownThumbnailMetadata(
                fileName: fileName,
                fileExtension: request.fileURL.pathExtension,
                heading: nil,
                approximateLineCount: 0,
                isTruncated: false,
                isUTF8: false
            )
        }

        let reply = QLThumbnailReply(
            contextSize: size,
            currentContextDrawing: {
                AppLog.thumbnail.info("thumbnail drawing start file=\(fileName, privacy: .private)")
                defer {
                    AppLog.thumbnail.info("thumbnail drawing done file=\(fileName, privacy: .private)")
                }

                MarkdownThumbnailRenderer.draw(
                    metadata: metadata,
                    size: size,
                    palette: .v0Light
                )
                return true
            }
        )
        AppLog.thumbnail.info("thumbnail reply created file=\(fileName, privacy: .private)")

        handler(reply, nil)
    }
}
