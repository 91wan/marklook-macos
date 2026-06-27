import MarkdownCore
import XCTest

final class MarkdownPreviewRenderingTests: XCTestCase {
    func testRendererProducesSafeHTMLForPreview() throws {
        let renderer = MarkdownPreviewRenderer()
        let document = MarkdownDocument(source: """
        # Preview
        <script>alert(1)</script>
        ![remote](https://example.com/a.png)
        [site](https://example.com)
        """)

        let result = try renderer.render(document)

        XCTAssertTrue(result.html.contains("<h1 id=\"preview\">Preview</h1>"))
        XCTAssertFalse(result.html.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(result.html.contains("href=\"https://"))
        XCTAssertFalse(result.html.contains("src=\"https://"))
        XCTAssertTrue(result.html.contains("Remote image blocked"))
    }

    func testRendererUsesQuickLookFastModeDefaults() throws {
        let renderer = MarkdownPreviewRenderer()
        let source = String(repeating: "a", count: 1_000_001)

        let result = try renderer.render(MarkdownDocument(source: source))

        XCTAssertTrue(result.usedFastMode)
        XCTAssertEqual(result.sourceByteCount, 1_000_001)
        XCTAssertLessThan(result.html.utf8.count, source.utf8.count)
    }
}
