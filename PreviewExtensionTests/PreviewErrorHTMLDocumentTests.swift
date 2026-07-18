import Foundation
import XCTest

final class PreviewErrorHTMLDocumentTests: XCTestCase {
    func testErrorHTMLDocumentEscapesUnsafeText() {
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview <script>alert(1)</script>",
            message: "Could not read /tmp/marklook-private/private.md: <b>bad</b> & \"quoted\""
        )

        XCTAssertTrue(html.contains("Preview &lt;script&gt;alert(1)&lt;/script&gt;"))
        XCTAssertTrue(html.contains("&lt;b&gt;bad&lt;/b&gt; &amp; &quot;quoted&quot;"))
        XCTAssertFalse(html.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(html.localizedCaseInsensitiveContains("<b>bad</b>"))
    }

    func testErrorHTMLDocumentContainsNoExecutableOrExternalResourceReferences() {
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview unavailable",
            message: "Could not read /tmp/marklook-private/private.md"
        )

        XCTAssertFalse(html.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(html.localizedCaseInsensitiveContains("href="))
        XCTAssertFalse(html.localizedCaseInsensitiveContains("src="))
        XCTAssertFalse(html.contains("/tmp/marklook-private/private.md"))
        XCTAssertTrue(html.contains("Content-Security-Policy"))
    }

    func testErrorHTMLDocumentRedactsFileURLPaths() {
        let privatePath = "/" + ["Users", "example", "Documents", "private.md"].joined(separator: "/")
        let fileURL = URL(fileURLWithPath: privatePath).absoluteString
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview unavailable",
            message: "Could not read \(fileURL): permission denied"
        )

        XCTAssertFalse(html.contains(fileURL))
        XCTAssertFalse(html.contains(privatePath))
        XCTAssertTrue(html.contains("Could not read private.md: permission denied"))
    }

    func testErrorHTMLDocumentRedactsPercentEncodedFileURLPaths() {
        let privatePath = "/" + ["Users", "example", "Private Notes", "review.md"].joined(separator: "/")
        let fileURL = URL(fileURLWithPath: privatePath).absoluteString
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview unavailable",
            message: "Could not read \(fileURL)"
        )

        XCTAssertFalse(html.contains(fileURL))
        XCTAssertFalse(html.contains("Private%20Notes"))
        XCTAssertTrue(html.contains("Could not read review.md"))
    }

    func testErrorHTMLDocumentRedactsIPv6AuthorityFileURLPaths() {
        let privatePath = "/" + ["Users", "example", "Documents", "private.md"].joined(separator: "/")
        let fileURL = "file://[::1]\(privatePath)"
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview unavailable",
            message: "Could not read \(fileURL): permission denied"
        )

        XCTAssertFalse(html.contains(fileURL))
        XCTAssertFalse(html.contains(privatePath))
        XCTAssertFalse(html.contains("[::1]"))
        XCTAssertTrue(html.contains("Could not read private.md: permission denied"))
    }

    func testErrorHTMLDocumentRedactsWindowsDriveFileURLPaths() {
        let privatePath = "/" + ["Users", "example", "Documents", "private.md"].joined(separator: "/")
        let fileURL = "file:///C:\(privatePath)"
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview unavailable",
            message: "Could not read \(fileURL): permission denied"
        )

        XCTAssertFalse(html.contains(fileURL))
        XCTAssertFalse(html.contains(privatePath))
        XCTAssertTrue(html.contains("Could not read private.md: permission denied"))
    }

    func testErrorHTMLDocumentRedactsColonAuthorityFileURLPaths() {
        let privatePath = "/" + ["Users", "example", "Documents", "private.md"].joined(separator: "/")
        let fileURL = "file://host:8443\(privatePath)"
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview unavailable",
            message: "Could not read \(fileURL): permission denied"
        )

        XCTAssertFalse(html.contains(fileURL))
        XCTAssertFalse(html.contains(privatePath))
        XCTAssertTrue(html.contains("Could not read private.md: permission denied"))
    }

    func testErrorHTMLDocumentRedactsEntireMalformedFileURLToken() {
        let privatePath = "/" + ["Users", "example", "Documents", "private.md"].joined(separator: "/")
        let malformedFileURL = "file://[::1\(privatePath)"
        let html = PreviewErrorHTMLDocument.html(
            title: "Preview unavailable",
            message: "Could not read \(malformedFileURL): permission denied"
        )

        XCTAssertFalse(html.contains(malformedFileURL))
        XCTAssertFalse(html.contains(privatePath))
        XCTAssertTrue(html.contains("Could not read &lt;redacted-file&gt;: permission denied"))
    }
}
