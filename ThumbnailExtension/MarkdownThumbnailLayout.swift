import CoreGraphics

struct MarkdownThumbnailLayout: Equatable {
    let canvasRect: CGRect
    let cardRect: CGRect
    let badgeRect: CGRect
    let extensionRect: CGRect
    let titleRect: CGRect
    let footerRect: CGRect

    static func make(size: CGSize) -> MarkdownThumbnailLayout {
        let canvasRect = CGRect(origin: .zero, size: size)
        let shortestSide = max(1, min(size.width, size.height))
        let outerInset = max(8, shortestSide * 0.075)
        let cardRect = canvasRect.insetBy(dx: outerInset, dy: outerInset)
        let innerInset = max(6, shortestSide * 0.055)
        let rowGap = max(5, shortestSide * 0.040)

        let topRowHeight = max(20, cardRect.height * 0.18)
        let footerHeight = max(14, cardRect.height * 0.11)

        let badgeHeight = min(topRowHeight, max(18, cardRect.height * 0.19))
        let badgeWidth = min(cardRect.width * 0.34, badgeHeight * 1.85)
        let badgeRect = CGRect(
            x: cardRect.minX + innerInset,
            y: cardRect.maxY - innerInset - badgeHeight,
            width: badgeWidth,
            height: badgeHeight
        )

        let extensionRect = CGRect(
            x: badgeRect.maxX + rowGap,
            y: badgeRect.minY,
            width: max(1, cardRect.maxX - innerInset - badgeRect.maxX - rowGap),
            height: badgeRect.height
        )

        let footerRect = CGRect(
            x: cardRect.minX + innerInset,
            y: cardRect.minY + innerInset,
            width: max(1, cardRect.width - innerInset * 2),
            height: footerHeight
        )

        let titleY = footerRect.maxY + rowGap
        let titleMaxY = badgeRect.minY - rowGap
        let titleRect = CGRect(
            x: cardRect.minX + innerInset,
            y: titleY,
            width: max(1, cardRect.width - innerInset * 2),
            height: max(1, titleMaxY - titleY)
        )

        return MarkdownThumbnailLayout(
            canvasRect: canvasRect,
            cardRect: cardRect,
            badgeRect: badgeRect,
            extensionRect: extensionRect,
            titleRect: titleRect,
            footerRect: footerRect
        )
    }
}
