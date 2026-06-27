import XCTest
@testable import MarkdownCore

final class TableOfContentsTests: XCTestCase {
    private let renderer = MarkdownRenderer()

    func testExtractsH1H2H3() throws {
        let result = try renderer.render(MarkdownDocument(source: "# One\n## Two\n### Three"))

        XCTAssertEqual(result.tableOfContents.map(\.title), ["One", "Two", "Three"])
        XCTAssertEqual(result.tableOfContents.map(\.level), [1, 2, 3])
    }

    func testStableSlugGeneration() {
        XCTAssertEqual(TableOfContents.slug(for: "Hello, MarkLook!"), "hello-marklook")
    }

    func testDuplicateHeadingsGetUniqueSlugs() throws {
        let result = try renderer.render(MarkdownDocument(source: "# Intro\n# Intro\n# Intro"))

        XCTAssertEqual(result.tableOfContents.map(\.id), ["intro", "intro-2", "intro-3"])
    }

    func testCodeBlockHeadingsAreIgnored() throws {
        let result = try renderer.render(MarkdownDocument(source: """
        ```
        # Not a heading
        ```
        # Real heading
        """))

        XCTAssertEqual(result.tableOfContents.map(\.title), ["Real heading"])
    }
}
