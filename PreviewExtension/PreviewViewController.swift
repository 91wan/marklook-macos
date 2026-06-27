import Cocoa
import Quartz

final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    override func loadView() {
        view = PreviewHTMLView(
            fileName: "MarkLook Preview Extension Loaded",
            filePath: "Waiting for a Quick Look file.",
            detail: "Rendering is implemented in Issue #4."
        )
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            let sizeText = values.fileSize.map(Self.formattedByteCount) ?? "Unknown size"
            view = PreviewHTMLView(
                fileName: url.lastPathComponent,
                filePath: url.path,
                detail: "MarkLook Preview Extension Loaded\n\(sizeText)\nRendering is implemented in Issue #4."
            )
            handler(nil)
        } catch {
            view = PreviewErrorView(
                title: "Preview unavailable",
                message: error.localizedDescription
            )
            handler(error)
        }
    }

    private static func formattedByteCount(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}
