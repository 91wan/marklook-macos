import XCTest

final class PreviewErrorHTMLDocumentTests: XCTestCase {
    func testErrorHTMLDocumentEscapesUnsafeText() {
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview <script>alert(1)</script>",
            message: "Could not read /Users/example/private.md: <b>bad</b> & \"quoted\""
        )

        XCTAssertTrue(html.contains("Preview &lt;script&gt;alert(1)&lt;/script&gt;"))
        XCTAssertTrue(html.contains("&lt;b&gt;bad&lt;/b&gt; &amp; &quot;quoted&quot;"))
        XCTAssertFalse(html.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(html.localizedCaseInsensitiveContains("<b>bad</b>"))
    }

    func testErrorHTMLDocumentContainsNoExecutableOrExternalResourceReferences() {
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview unavailable",
            message: "Could not read /Users/example/private.md"
        )

        XCTAssertFalse(html.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(html.localizedCaseInsensitiveContains("href="))
        XCTAssertFalse(html.localizedCaseInsensitiveContains("src="))
        XCTAssertFalse(html.contains("/Users/example/private.md"))
        XCTAssertTrue(html.contains("Content-Security-Policy"))
    }
}
