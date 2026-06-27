import WebKit
import XCTest

final class PreviewNavigationPolicyTests: XCTestCase {
    func testAllowsOnlyAboutBlank() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: URL(string: "about:blank")),
            .allow
        )
    }

    func testAllowsNilInitialLoad() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: nil),
            .allow
        )
    }

    func testCancelsLinkActivation() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .linkActivated, requestURL: URL(string: "https://example.com")),
            .cancel
        )
    }

    func testCancelsFormSubmission() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .formSubmitted, requestURL: URL(string: "https://example.com")),
            .cancel
        )
    }

    func testCancelsFormResubmission() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .formResubmitted, requestURL: URL(string: "https://example.com")),
            .cancel
        )
    }

    func testCancelsAboutSrcdocOrOtherAboutURLs() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: URL(string: "about:srcdoc")),
            .cancel
        )
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: URL(string: "about:config")),
            .cancel
        )
    }

    func testCancelsDataURLNavigation() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: URL(string: "data:text/html,<h1>x</h1>")),
            .cancel
        )
    }

    func testCancelsXAppleNavigation() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: URL(string: "x-apple.systempreferences:com.apple.preference.security")),
            .cancel
        )
    }

    func testCancelsItmsServicesNavigation() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: URL(string: "itms-services://?action=download-manifest")),
            .cancel
        )
    }

    func testCancelsExternalOtherNavigation() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: URL(string: "https://example.com")),
            .cancel
        )
    }

    func testCancelsFileNavigation() {
        XCTAssertEqual(
            PreviewNavigationPolicy.decision(for: .other, requestURL: URL(fileURLWithPath: "/etc/passwd")),
            .cancel
        )
    }
}
