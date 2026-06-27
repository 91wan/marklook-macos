import XCTest
@testable import MarkdownCore

final class FrontMatterTests: XCTestCase {
    func testParsesYAMLFrontMatterBetweenMarkers() {
        let document = MarkdownDocument(source: """
        ---
        title: Launch Notes
        author: MarkLook
        ---
        # Body
        """)

        XCTAssertEqual(document.frontMatter?.fields["title"], "Launch Notes")
        XCTAssertEqual(document.frontMatter?.fields["author"], "MarkLook")
    }

    func testPreservesMarkdownBodyAfterFrontMatter() {
        let document = MarkdownDocument(source: """
        ---
        title: Launch Notes
        ---

        # Body
        Content.
        """)

        XCTAssertEqual(document.source, "\n# Body\nContent.")
    }

    func testIgnoresMarkerInsideBody() {
        let source = """
        Intro
        ---
        Still body
        """
        let document = MarkdownDocument(source: source)

        XCTAssertNil(document.frontMatter)
        XCTAssertEqual(document.source, source)
    }

    func testHandlesNoFrontMatter() {
        let document = MarkdownDocument(source: "# Plain")

        XCTAssertNil(document.frontMatter)
        XCTAssertEqual(document.source, "# Plain")
    }
}
