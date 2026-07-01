import AppKit

enum MarkdownThumbnailRenderer {
    static func render(
        metadata: MarkdownThumbnailMetadata,
        size: CGSize,
        palette: MarkdownThumbnailPalette = .v0Light
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        draw(metadata: metadata, size: size, palette: palette)
        return image
    }

    static func draw(
        metadata: MarkdownThumbnailMetadata,
        size: CGSize,
        palette: MarkdownThumbnailPalette = .v0Light
    ) {
        let layout = MarkdownThumbnailLayout.make(size: size)
        let shortestSide = max(1, min(size.width, size.height))
        let radius = max(8, shortestSide * 0.035)

        palette.canvas.setFill()
        NSBezierPath(rect: layout.canvasRect).fill()

        let cardPath = NSBezierPath(roundedRect: layout.cardRect, xRadius: radius, yRadius: radius)
        palette.card.setFill()
        cardPath.fill()
        palette.border.setStroke()
        cardPath.lineWidth = max(1, shortestSide * 0.004)
        cardPath.stroke()

        drawBadge(in: layout.badgeRect, cornerRadius: radius * 0.7, shortestSide: shortestSide, palette: palette)

        let extensionLabel = metadata.fileExtension.isEmpty ? ".md" : ".\(metadata.fileExtension)"
        drawText(
            extensionLabel,
            in: layout.extensionRect,
            font: NSFont.monospacedSystemFont(ofSize: max(8, min(24, shortestSide * 0.048)), weight: .semibold),
            color: palette.secondaryText,
            lineLimit: 1
        )

        let title = displayTitle(for: metadata, maxCharacters: maxTitleCharacters(for: shortestSide))
        let titleRect = CGRect(
            x: layout.titleRect.minX,
            y: layout.titleRect.minY,
            width: layout.titleRect.width,
            height: layout.titleRect.height
        )
        drawText(
            title,
            in: titleRect,
            font: NSFont.systemFont(ofSize: max(10, min(34, shortestSide * 0.062)), weight: .semibold),
            color: palette.primaryText,
            lineLimit: shortestSide < 300 ? 2 : 3
        )

        let lineSummary = lineSummary(for: metadata)
        let footer = metadata.isUTF8 ? lineSummary : "\(lineSummary) - UTF-8 unavailable"
        drawText(
            footer,
            in: layout.footerRect,
            font: NSFont.systemFont(ofSize: max(8, min(22, shortestSide * 0.040)), weight: .medium),
            color: palette.secondaryText,
            lineLimit: 1
        )
    }

    static func displayTitle(for metadata: MarkdownThumbnailMetadata, maxCharacters: Int) -> String {
        let source = metadata.heading ?? metadata.fileName
        let collapsed = source
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard collapsed.count > maxCharacters else {
            return collapsed
        }
        return String(collapsed.prefix(max(1, maxCharacters))) + "..."
    }

    private static func drawBadge(
        in rect: CGRect,
        cornerRadius: CGFloat,
        shortestSide: CGFloat,
        palette: MarkdownThumbnailPalette
    ) {
        let badgePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        palette.badge.setFill()
        badgePath.fill()

        drawText(
            "MD",
            in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08),
            font: NSFont.systemFont(ofSize: max(11, min(42, shortestSide * 0.080)), weight: .heavy),
            color: palette.badgeText,
            lineLimit: 1,
            alignment: .center
        )
    }

    private static func drawText(
        _ text: String,
        in rect: CGRect,
        font: NSFont,
        color: NSColor,
        lineLimit: Int,
        alignment: NSTextAlignment = .natural
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = lineLimit <= 1 ? .byTruncatingTail : .byWordWrapping
        paragraph.maximumLineHeight = font.pointSize * 1.15
        paragraph.minimumLineHeight = font.pointSize * 1.15

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    private static func lineSummary(for metadata: MarkdownThumbnailMetadata) -> String {
        let suffix = metadata.isTruncated ? "+" : ""
        let unit = metadata.approximateLineCount == 1 && !metadata.isTruncated ? "line" : "lines"
        return "\(metadata.approximateLineCount)\(suffix) \(unit)"
    }

    private static func maxTitleCharacters(for shortestSide: CGFloat) -> Int {
        switch shortestSide {
        case ..<180:
            return 28
        case ..<360:
            return 44
        case ..<720:
            return 72
        default:
            return 96
        }
    }
}
