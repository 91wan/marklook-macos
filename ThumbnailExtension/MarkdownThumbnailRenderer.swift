import AppKit

enum MarkdownThumbnailRenderer {
    static func render(
        metadata: MarkdownThumbnailMetadata,
        size: CGSize,
        appearance: NSAppearance? = nil
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer {
            image.unlockFocus()
        }

        draw(metadata: metadata, size: size, appearance: appearance)
        return image
    }

    static func draw(
        metadata: MarkdownThumbnailMetadata,
        size: CGSize,
        appearance: NSAppearance? = nil
    ) {
        let previousAppearance = NSAppearance.current
        if let appearance {
            NSAppearance.current = appearance
        }
        defer {
            NSAppearance.current = previousAppearance
        }

        let rect = CGRect(origin: .zero, size: size)
        NSColor.textBackgroundColor.setFill()
        NSBezierPath(rect: rect).fill()

        let shortestSide = max(1, min(size.width, size.height))
        let inset = max(10, shortestSide * 0.075)
        let cardRect = rect.insetBy(dx: inset, dy: inset)
        let radius = max(8, shortestSide * 0.035)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: radius, yRadius: radius)
        NSColor.controlBackgroundColor.setFill()
        cardPath.fill()
        NSColor.separatorColor.setStroke()
        cardPath.lineWidth = max(1, shortestSide * 0.004)
        cardPath.stroke()

        let badgeSize = CGSize(width: cardRect.width * 0.33, height: cardRect.height * 0.2)
        let badgeRect = CGRect(
            x: cardRect.minX + inset * 0.75,
            y: cardRect.maxY - inset * 0.75 - badgeSize.height,
            width: badgeSize.width,
            height: badgeSize.height
        )
        drawBadge(in: badgeRect, cornerRadius: radius * 0.7, shortestSide: shortestSide)

        let extensionLabel = metadata.fileExtension.isEmpty ? ".md" : ".\(metadata.fileExtension)"
        drawText(
            extensionLabel,
            in: CGRect(
                x: badgeRect.maxX + inset * 0.55,
                y: badgeRect.minY + badgeRect.height * 0.18,
                width: max(0, cardRect.maxX - badgeRect.maxX - inset * 1.3),
                height: badgeRect.height * 0.65
            ),
            font: NSFont.monospacedSystemFont(ofSize: max(12, shortestSide * 0.055), weight: .semibold),
            color: .secondaryLabelColor,
            lineLimit: 1
        )

        let title = metadata.heading ?? metadata.fileName
        let titleRect = CGRect(
            x: cardRect.minX + inset * 0.75,
            y: cardRect.minY + cardRect.height * 0.29,
            width: cardRect.width - inset * 1.5,
            height: cardRect.height * 0.32
        )
        drawText(
            title,
            in: titleRect,
            font: NSFont.systemFont(ofSize: max(15, shortestSide * 0.07), weight: .semibold),
            color: .labelColor,
            lineLimit: shortestSide < 300 ? 2 : 3
        )

        let lineSummary = lineSummary(for: metadata)
        let footer = metadata.isUTF8 ? lineSummary : "\(lineSummary) - UTF-8 unavailable"
        drawText(
            footer,
            in: CGRect(
                x: cardRect.minX + inset * 0.75,
                y: cardRect.minY + inset * 0.8,
                width: cardRect.width - inset * 1.5,
                height: max(16, cardRect.height * 0.1)
            ),
            font: NSFont.systemFont(ofSize: max(10, shortestSide * 0.045), weight: .medium),
            color: .secondaryLabelColor,
            lineLimit: 1
        )
    }

    private static func drawBadge(
        in rect: CGRect,
        cornerRadius: CGFloat,
        shortestSide: CGFloat
    ) {
        let badgePath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.controlAccentColor.setFill()
        badgePath.fill()

        drawText(
            "MD",
            in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.08),
            font: NSFont.systemFont(ofSize: max(18, shortestSide * 0.085), weight: .heavy),
            color: .white,
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
}
