import XCTest
@testable import MarkdownCore

final class HTMLDocumentBuilderTests: XCTestCase {
    private let builder = HTMLDocumentBuilder()

    func testIncludesCharset() {
        let html = builder.build(title: "MarkLook", trustedBodyHTML: "<p>Body</p>")

        XCTAssertTrue(html.contains("<meta charset=\"utf-8\">"))
    }

    func testIncludesCSP() {
        let html = builder.build(title: "MarkLook", trustedBodyHTML: "<p>Body</p>")

        XCTAssertTrue(html.contains("default-src 'none'; img-src 'none'; style-src 'unsafe-inline';"))
    }

    func testIncludesInlineCSS() {
        let html = builder.build(title: "MarkLook", trustedBodyHTML: "<p>Body</p>")

        XCTAssertTrue(html.contains("<style>"))
        XCTAssertTrue(html.contains("font-family"))
    }

    func testDoesNotIncludeExternalCSS() {
        let html = builder.build(title: "MarkLook", trustedBodyHTML: "<p>Body</p>")

        XCTAssertFalse(html.localizedCaseInsensitiveContains("<link rel=\"stylesheet\""))
    }

    func testDoesNotIncludeScript() {
        let html = builder.build(title: "MarkLook", trustedBodyHTML: "<p>Body</p>")

        XCTAssertFalse(html.localizedCaseInsensitiveContains("<script"))
    }

    func testOutputIsCompleteHTMLDocument() {
        let html = builder.build(title: "MarkLook", trustedBodyHTML: "<p>Body</p>")

        XCTAssertTrue(html.hasPrefix("<!doctype html>"))
        XCTAssertTrue(html.contains("<html"))
        XCTAssertTrue(html.contains("</html>"))
    }
}
