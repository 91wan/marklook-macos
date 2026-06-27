import WebKit
import XCTest

final class PreviewNavigationPolicyTests: XCTestCase {
    func testAllowsInitialAboutBlankLoad() {
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
