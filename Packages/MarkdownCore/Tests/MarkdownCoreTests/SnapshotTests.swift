import XCTest
@testable import MarkdownCore

final class SnapshotTests: XCTestCase {
    func testRenderedDocumentIsSelfContainedAndSafe() throws {
        let source = """
        ---
        title: Safe Snapshot
        ---
        # Safe Snapshot

        - [x] Build shell

        | Item | Status |
        | --- | --- |
        | Preview | Pending |

        ![remote](https://example.com/a.png)
        <script>alert(1)</script>
        """

        let result = try MarkdownRenderer().render(MarkdownDocument(source: source))

        XCTAssertTrue(result.html.contains("<!doctype html>"))
        XCTAssertTrue(result.html.contains("<table>"))
        XCTAssertTrue(result.html.contains("Remote image blocked"))
        XCTAssertFalse(result.html.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(result.html.contains("src=\"https://"))
        XCTAssertEqual(result.frontMatter?.fields["title"], "Safe Snapshot")
    }
}
