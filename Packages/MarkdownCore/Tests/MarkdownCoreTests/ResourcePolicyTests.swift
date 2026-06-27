import XCTest
@testable import MarkdownCore

final class ResourcePolicyTests: XCTestCase {
    private let renderer = MarkdownRenderer()

    func testHTTPSImageBlockedByDefault() throws {
        let result = try renderer.render(MarkdownDocument(source: "![remote](https://example.com/a.png)"))

        XCTAssertFalse(result.html.contains("src=\"https://example.com/a.png\""))
        XCTAssertTrue(result.html.contains("Remote image blocked"))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .blockedRemoteResource })
    }

    func testHTTPImageBlockedByDefault() throws {
        let result = try renderer.render(MarkdownDocument(source: "![remote](http://example.com/a.png)"))

        XCTAssertFalse(result.html.contains("src=\"http://example.com/a.png\""))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .blockedRemoteResource })
    }

    func testDataImageAllowedOnlyWhenExplicitlyAllowed() throws {
        let source = "![inline](data:image/png;base64,AAAA)"

        let blocked = try renderer.render(MarkdownDocument(source: source))
        XCTAssertFalse(blocked.html.contains("src=\"data:image/png;base64,AAAA\""))

        let allowed = try renderer.render(
            MarkdownDocument(source: source),
            options: RenderOptions(allowRemoteResources: true)
        )
        XCTAssertTrue(allowed.html.contains("src=\"data:image/png;base64,AAAA\""))
    }

    func testJavascriptLinkBlocked() throws {
        let result = try renderer.render(MarkdownDocument(source: "[bad](javascript:alert(1))"))

        XCTAssertFalse(result.html.contains("javascript:"))
        XCTAssertTrue(result.html.contains("href=\"#\""))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .unsafeLink })
    }

    func testRawHTMLScriptBlocked() throws {
        let result = try renderer.render(MarkdownDocument(source: "<script>alert(1)</script>"))

        XCTAssertFalse(result.html.localizedCaseInsensitiveContains("<script"))
        XCTAssertTrue(result.html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .rawHTMLBlocked })
    }

    func testIFrameBlocked() throws {
        let result = try renderer.render(MarkdownDocument(source: "<iframe src=\"https://example.com\"></iframe>"))

        XCTAssertFalse(result.html.localizedCaseInsensitiveContains("<iframe"))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .rawHTMLBlocked })
    }

    func testEventAttributesBlocked() throws {
        let result = try renderer.render(MarkdownDocument(source: "<img src=x onerror=alert(1)>"))

        XCTAssertFalse(result.html.localizedCaseInsensitiveContains("onerror="))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .rawHTMLBlocked })
    }
}
