import XCTest

final class PreviewErrorViewTests: XCTestCase {
    @MainActor
    func testErrorViewContainsVisibleTextControls() {
        let view = PreviewErrorView(title: "Preview unavailable", message: "The file is not UTF-8.")

        XCTAssertFalse(view.subviews.isEmpty)
    }
}
