import AppKit
import XCTest

final class MarkdownThumbnailLayoutTests: XCTestCase {
    func testLayoutRectsDoNotOverlapAtRequiredSizes() {
        for side in [128, 256, 512, 1024] {
            let layout = MarkdownThumbnailLayout.make(size: CGSize(width: side, height: side))

            assertLayoutRectsInsideCard(layout, side: side)
            XCTAssertFalse(layout.badgeRect.intersects(layout.titleRect), "badge/title overlap at \(side)")
            XCTAssertFalse(layout.badgeRect.intersects(layout.footerRect), "badge/footer overlap at \(side)")
            XCTAssertFalse(layout.titleRect.intersects(layout.footerRect), "title/footer overlap at \(side)")
        }
    }

    func testBadgeTitleAndFooterAreVerticallySeparated() {
        let layout = MarkdownThumbnailLayout.make(size: CGSize(width: 512, height: 512))

        XCTAssertGreaterThanOrEqual(layout.badgeRect.minY, layout.titleRect.maxY)
        XCTAssertGreaterThanOrEqual(layout.titleRect.minY, layout.footerRect.maxY)
    }

    private func assertLayoutRectsInsideCard(_ layout: MarkdownThumbnailLayout, side: Int) {
        for rect in [layout.badgeRect, layout.extensionRect, layout.titleRect, layout.footerRect] {
            XCTAssertTrue(layout.cardRect.contains(rect), "rect \(rect) escapes card at \(side)")
            XCTAssertGreaterThan(rect.width, 0, "rect width must be positive at \(side)")
            XCTAssertGreaterThan(rect.height, 0, "rect height must be positive at \(side)")
        }
    }
}
