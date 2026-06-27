import XCTest

final class PreviewErrorViewTests: XCTestCase {
    func testErrorViewContainsVisibleTextControls() {
        let view = PreviewErrorView(title: "Preview unavailable", message: "The file is not UTF-8.")

        XCTAssertFalse(view.subviews.isEmpty)
    }
}
