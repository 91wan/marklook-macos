import AppKit
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let size = request.maximumSize
        let fileName = request.fileURL.lastPathComponent

        let reply = QLThumbnailReply(contextSize: size) {
            Self.drawThumbnail(size: size, fileName: fileName)
            return true
        }

        handler(reply, nil)
    }

    private static func drawThumbnail(size: CGSize, fileName: String) {
        let rect = CGRect(origin: .zero, size: size)
        NSColor.textBackgroundColor.setFill()
        NSBezierPath(rect: rect).fill()

        let inset = max(8, min(size.width, size.height) * 0.08)
        let cardRect = rect.insetBy(dx: inset, dy: inset)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 10, yRadius: 10)
        NSColor.controlBackgroundColor.setFill()
        cardPath.fill()
        NSColor.separatorColor.setStroke()
        cardPath.lineWidth = 1
        cardPath.stroke()

        let badge = "MD" as NSString
        let badgeFontSize = max(20, min(size.width, size.height) * 0.24)
        let badgeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: badgeFontSize, weight: .bold),
            .foregroundColor: NSColor.labelColor
        ]
        let badgeSize = badge.size(withAttributes: badgeAttributes)
        let badgeRect = CGRect(
            x: cardRect.midX - badgeSize.width / 2,
            y: cardRect.midY - badgeSize.height / 2 + inset * 0.4,
            width: badgeSize.width,
            height: badgeSize.height
        )
        badge.draw(in: badgeRect, withAttributes: badgeAttributes)

        let name = fileName as NSString
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(10, min(size.width, size.height) * 0.08)),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let nameRect = CGRect(
            x: cardRect.minX + inset,
            y: cardRect.minY + inset,
            width: max(0, cardRect.width - inset * 2),
            height: max(14, inset * 1.4)
        )
        name.draw(in: nameRect, withAttributes: nameAttributes)
    }
}
