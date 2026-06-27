import XCTest
@testable import MarkdownCore

final class MarkdownRendererTests: XCTestCase {
    private let renderer = MarkdownRenderer()

    func testHeadingRendersToH1H2H3() throws {
        let result = try renderer.render(MarkdownDocument(source: "# One\n## Two\n### Three"))

        XCTAssertTrue(result.html.contains("<h1 id=\"one\">One</h1>"))
        XCTAssertTrue(result.html.contains("<h2 id=\"two\">Two</h2>"))
        XCTAssertTrue(result.html.contains("<h3 id=\"three\">Three</h3>"))
    }

    func testUnorderedListRenders() throws {
        let result = try renderer.render(MarkdownDocument(source: "- Alpha\n- Beta"))

        XCTAssertTrue(result.html.contains("<ul>"))
        XCTAssertTrue(result.html.contains("<li>Alpha</li>"))
        XCTAssertTrue(result.html.contains("<li>Beta</li>"))
    }

    func testOrderedListRenders() throws {
        let result = try renderer.render(MarkdownDocument(source: "1. Alpha\n2. Beta"))

        XCTAssertTrue(result.html.contains("<ol>"))
        XCTAssertTrue(result.html.contains("<li>Alpha</li>"))
        XCTAssertTrue(result.html.contains("<li>Beta</li>"))
    }

    func testBlockquoteRenders() throws {
        let result = try renderer.render(MarkdownDocument(source: "> A careful quote"))

        XCTAssertTrue(result.html.contains("<blockquote>"))
        XCTAssertTrue(result.html.contains("A careful quote"))
    }

    func testFencedCodeBlockRendersAndEscapesHTMLInsideCode() throws {
        let result = try renderer.render(MarkdownDocument(source: """
        ```swift
        let x = "<script>"
        ```
        """))

        XCTAssertTrue(result.html.contains("<pre><code"))
        XCTAssertTrue(result.html.contains("&lt;script&gt;"))
        XCTAssertFalse(result.html.contains("let x = \"<script>\""))
    }

    func testInlineCodeRenders() throws {
        let result = try renderer.render(MarkdownDocument(source: "Use `swift test` now."))

        XCTAssertTrue(result.html.contains("<code>swift test</code>"))
    }

    func testGFMTableRenders() throws {
        let result = try renderer.render(MarkdownDocument(source: """
        | Name | Status |
        | --- | --- |
        | Preview | Shell |
        """))

        XCTAssertTrue(result.html.contains("<table>"))
        XCTAssertTrue(result.html.contains("<thead>"))
        XCTAssertTrue(result.html.contains("<tbody>"))
        XCTAssertTrue(result.html.contains("<td>Shell</td>"))
    }

    func testTaskListRendersDisabledCheckbox() throws {
        let result = try renderer.render(MarkdownDocument(source: "- [x] Build app\n- [ ] Render later"))

        XCTAssertTrue(result.html.contains("type=\"checkbox\""))
        XCTAssertTrue(result.html.contains("disabled"))
        XCTAssertTrue(result.html.contains("Build app"))
    }

    func testHorizontalRuleRenders() throws {
        let result = try renderer.render(MarkdownDocument(source: "Before\n\n---\n\nAfter"))

        XCTAssertTrue(result.html.contains("<hr>"))
    }

    func testLongMarkdownReturnsUsedFastModeWhenAboveThreshold() throws {
        let options = RenderOptions(fastModeByteThreshold: 8)
        let result = try renderer.render(MarkdownDocument(source: "This document is long enough."), options: options)

        XCTAssertTrue(result.usedFastMode)
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .fastMode })
    }
}
