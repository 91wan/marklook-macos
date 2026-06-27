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

    func testWritesRendererSecurityFixtureWhenRequested() throws {
        guard let path = ProcessInfo.processInfo.environment["MARKLOOK_RENDERER_SECURITY_FIXTURE"] else {
            return
        }

        let source = """
        # Safe Fixture
        <script>alert(1)</script>
        <iframe src="https://example.com"></iframe>
        <img src=x onerror=alert(1)>
        ![remote](https://example.com/a.png)
        ![data](data:image/svg+xml,<svg onload=alert(1) />)
        [bad](javascript:alert(1))
        [file](file:///etc/passwd)
        [settings](x-apple.systempreferences:com.apple.preference.security)
        [install](itms-services://?action=download-manifest&url=https://example.com/a.plist)
        """
        let result = try MarkdownRenderer().render(MarkdownDocument(source: source))

        try result.html.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
