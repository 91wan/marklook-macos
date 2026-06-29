import AppKit
import XCTest

final class MarkdownThumbnailRendererTests: XCTestCase {
    func testRenders256WithoutCrash() {
        let image = render(size: CGSize(width: 256, height: 256))

        XCTAssertEqual(image.size, CGSize(width: 256, height: 256))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testRenders512WithoutCrash() {
        let image = render(size: CGSize(width: 512, height: 512))

        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testRenders1024WithoutCrash() {
        let image = render(size: CGSize(width: 1024, height: 1024))

        XCTAssertEqual(image.size, CGSize(width: 1024, height: 1024))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testRendersWithHeading() {
        let image = render(metadata: metadata(heading: "Architecture Notes"))

        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testRendersWithoutHeading() {
        let image = render(metadata: metadata(heading: nil))

        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testRendersTruncatedMetadata() {
        let image = render(metadata: metadata(heading: "Long Review", isTruncated: true))

        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testRendersDarkAppearanceWithoutCrash() {
        let image = render(appearance: NSAppearance(named: .darkAqua))

        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testRendersLightAppearanceWithoutCrash() {
        let image = render(appearance: NSAppearance(named: .aqua))

        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    private func render(
        metadata: MarkdownThumbnailMetadata? = nil,
        size: CGSize = CGSize(width: 512, height: 512),
        appearance: NSAppearance? = NSAppearance(named: .aqua)
    ) -> NSImage {
        MarkdownThumbnailRenderer.render(
            metadata: metadata ?? self.metadata(heading: "Release Notes"),
            size: size,
            appearance: appearance
        )
    }

    private func metadata(
        heading: String?,
        isTruncated: Bool = false
    ) -> MarkdownThumbnailMetadata {
        MarkdownThumbnailMetadata(
            fileName: "sample.md",
            fileExtension: "md",
            heading: heading,
            approximateLineCount: 42,
            isTruncated: isTruncated,
            isUTF8: true
        )
    }
}
