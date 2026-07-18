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

    func testNestedUnorderedListPreservesHierarchy() throws {
        let result = try renderer.render(MarkdownDocument(source: """
        - Parent
          - Child
            - Grandchild
        - Sibling
        """))

        XCTAssertTrue(result.html.contains("""
        <li>Parent
        <ul>
        <li>Child
        <ul>
        <li>Grandchild</li>
        </ul>
        </li>
        </ul>
        </li>
        """))
        XCTAssertTrue(result.html.contains("<li>Sibling</li>"))
    }

    func testNestedOrderedListRendersInsideUnorderedItem() throws {
        let result = try renderer.render(MarkdownDocument(source: """
        - Parent
          1. First
          2. Second
        - Sibling
        """))

        XCTAssertTrue(result.html.contains("""
        <li>Parent
        <ol>
        <li>First</li>
        <li>Second</li>
        </ol>
        </li>
        """))
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

    func testStrongAndEmphasisRender() throws {
        let result = try renderer.render(MarkdownDocument(
            source: "Use **strong** and *emphasis* in review docs."
        ))

        XCTAssertTrue(result.html.contains("<strong>strong</strong>"))
        XCTAssertTrue(result.html.contains("<em>emphasis</em>"))
    }

    func testNestedStrongAndEmphasisRender() throws {
        let result = try renderer.render(MarkdownDocument(
            source: "**Strong with *nested emphasis*.**"
        ))

        XCTAssertTrue(result.html.contains(
            "<strong>Strong with <em>nested emphasis</em>.</strong>"
        ))
    }

    func testStrikethroughRenders() throws {
        let result = try renderer.render(MarkdownDocument(source: "~~obsolete~~ current"))

        XCTAssertTrue(result.html.contains("<del>obsolete</del> current"))
    }

    func testUnclosedEmphasisDelimiterStaysLiteral() throws {
        let result = try renderer.render(MarkdownDocument(source: "Keep **unclosed literal"))

        XCTAssertTrue(result.html.contains("Keep **unclosed literal"))
        XCTAssertFalse(result.html.contains("<strong>"))
    }

    func testInlineCodeTakesPrecedenceOverEmphasis() throws {
        let result = try renderer.render(MarkdownDocument(source: "`**literal**` and **strong**"))

        XCTAssertTrue(result.html.contains("<code>**literal**</code>"))
        XCTAssertTrue(result.html.contains("<strong>strong</strong>"))
    }

    func testRawHTMLAroundEmphasisRemainsEscaped() throws {
        let result = try renderer.render(MarkdownDocument(
            source: "<script>**alert**</script>"
        ))

        XCTAssertFalse(result.html.localizedCaseInsensitiveContains("<script"))
        XCTAssertTrue(result.html.contains("&lt;script&gt;<strong>alert</strong>&lt;/script&gt;"))
    }

    func testManyUnclosedLinkOpenersRenderAsLiteralText() throws {
        let source = String(repeating: "[", count: 100_000)

        let result = try renderer.render(MarkdownDocument(source: source))

        XCTAssertFalse(result.usedFastMode)
        XCTAssertTrue(result.html.contains(source))
    }

    func testManyUnclosedLinkTargetsRenderAsLiteralText() throws {
        let source = String(repeating: "[x](", count: 20_000)

        let result = try renderer.render(MarkdownDocument(source: source))

        XCTAssertFalse(result.usedFastMode)
        XCTAssertTrue(result.html.contains(source))
    }

    func testUnclosedBracketKeepsInlineParsingActive() throws {
        let result = try renderer.render(MarkdownDocument(
            source: "[see `foo` bar"
        ))

        XCTAssertTrue(result.html.contains("[see"))
        XCTAssertTrue(result.html.contains("<code>foo</code>"))
    }

    func testMalformedBracketSequenceDoesNotHideLaterValidLink() throws {
        let result = try renderer.render(MarkdownDocument(
            source: "[[broken] then [site](https://example.com)"
        ))

        XCTAssertTrue(result.html.contains("[[broken] then"))
        XCTAssertTrue(result.html.contains("class=\"markdown-link\""))
        XCTAssertTrue(result.html.contains("data-url=\"https://example.com\""))
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
        let options = RenderOptions(fastModeByteThreshold: 8, fastModePreviewByteLimit: 32)
        let result = try renderer.render(MarkdownDocument(source: "This document is long enough."), options: options)

        XCTAssertTrue(result.usedFastMode)
        XCTAssertTrue(result.html.contains("Fast mode: document truncated for Quick Look responsiveness."))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .fastMode })
    }

    func testFastModeRunsBeforeFullRender() throws {
        let source = "# Intro\n\nVisible prefix.\n" + String(repeating: "A", count: 512) + "\nTAIL_SHOULD_NOT_RENDER"
        let options = RenderOptions(fastModeByteThreshold: 8, fastModePreviewByteLimit: 24)

        let result = try renderer.render(MarkdownDocument(source: source), options: options)

        XCTAssertTrue(result.usedFastMode)
        XCTAssertTrue(result.html.contains("<h1 id=\"intro\">Intro</h1>"))
        XCTAssertFalse(result.html.contains("TAIL_SHOULD_NOT_RENDER"))
    }

    func testFastModeTruncatesOutput() throws {
        let source = "Start\n" + String(repeating: "middle ", count: 40) + "END_SHOULD_NOT_RENDER"
        let options = RenderOptions(fastModeByteThreshold: 8, fastModePreviewByteLimit: 16)

        let result = try renderer.render(MarkdownDocument(source: source), options: options)

        XCTAssertTrue(result.usedFastMode)
        XCTAssertFalse(result.html.contains("END_SHOULD_NOT_RENDER"))
        XCTAssertTrue(result.html.contains("Fast mode: document truncated for Quick Look responsiveness."))
    }

    func testFastModeStillEscapesRawHTML() throws {
        let source = "<script>alert(1)</script>\n" + String(repeating: "content ", count: 40)
        let options = RenderOptions(fastModeByteThreshold: 8, fastModePreviewByteLimit: 64)

        let result = try renderer.render(MarkdownDocument(source: source), options: options)

        XCTAssertTrue(result.usedFastMode)
        XCTAssertFalse(result.html.localizedCaseInsensitiveContains("<script"))
        XCTAssertTrue(result.html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .rawHTMLBlocked })
    }

    func testFastModeStillBlocksImages() throws {
        let source = "![remote](https://example.com/a.png)\n" + String(repeating: "content ", count: 40)
        let options = RenderOptions(fastModeByteThreshold: 8, fastModePreviewByteLimit: 80)

        let result = try renderer.render(MarkdownDocument(source: source), options: options)

        XCTAssertTrue(result.usedFastMode)
        XCTAssertTrue(result.html.contains("Remote image blocked"))
        XCTAssertFalse(result.html.contains("src=\"https://example.com/a.png\""))
        XCTAssertTrue(result.diagnostics.contains { $0.kind == .blockedRemoteResource })
    }

    func testFastModeStillDoesNotEmitNavigableLinks() throws {
        let source = "[site](https://example.com)\n" + String(repeating: "content ", count: 40)
        let options = RenderOptions(fastModeByteThreshold: 8, fastModePreviewByteLimit: 80)

        let result = try renderer.render(MarkdownDocument(source: source), options: options)

        XCTAssertTrue(result.usedFastMode)
        XCTAssertFalse(result.html.contains("href=\"https://"))
        XCTAssertFalse(result.html.contains("href="))
        XCTAssertTrue(result.html.contains("class=\"markdown-link\""))
    }
}
