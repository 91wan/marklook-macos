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

    func testRendersLongHeadingWithoutCrash() {
        let image = render(metadata: metadata(heading: String(repeating: "Long Review Architecture Notes ", count: 24)))

        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testRendersLongFilenameWithoutCrash() {
        let image = render(metadata: metadata(fileName: String(repeating: "MarkLook_Codex_Round_Thumbnail_Determinism_", count: 10) + ".md", heading: nil))

        XCTAssertEqual(image.size, CGSize(width: 512, height: 512))
        XCTAssertNotNil(image.tiffRepresentation)
    }

    func testAmbientAppearanceDoesNotChangeThumbnailOutput() {
        let light = bitmapBytesForRender(ambientAppearance: NSAppearance(named: .aqua))
        let dark = bitmapBytesForRender(ambientAppearance: NSAppearance(named: .darkAqua))

        XCTAssertEqual(light, dark)
    }

    func testRenderingSameMetadataTwiceProducesSameBitmap() {
        let first = bitmapBytesForRender()
        let second = bitmapBytesForRender()

        XCTAssertEqual(first, second)
    }

    func testDisplayTitleCollapsesWhitespaceAndClampsLongHeading() {
        let source = metadata(heading: "  Release   Notes \n\n With     Extra       Whitespace  ")

        let title = MarkdownThumbnailRenderer.displayTitle(for: source, maxCharacters: 24)

        XCTAssertEqual(title, "Release Notes With Extra...")
        XCTAssertLessThanOrEqual(title.count, 27)
    }

    private func render(
        metadata: MarkdownThumbnailMetadata? = nil,
        size: CGSize = CGSize(width: 512, height: 512)
    ) -> NSImage {
        MarkdownThumbnailRenderer.render(
            metadata: metadata ?? self.metadata(heading: "Release Notes"),
            size: size
        )
    }

    private func bitmapBytesForRender(
        metadata: MarkdownThumbnailMetadata? = nil,
        ambientAppearance: NSAppearance? = nil
    ) -> Data {
        let previousAppearance = NSAppearance.current
        if let ambientAppearance {
            NSAppearance.current = ambientAppearance
        }
        defer {
            NSAppearance.current = previousAppearance
        }

        let image = render(metadata: metadata)
        var rect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            XCTFail("Expected rendered image to provide CGImage")
            return Data()
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        guard let bitmapData = bitmap.bitmapData else {
            XCTFail("Expected bitmap data")
            return Data()
        }
        return Data(bytes: bitmapData, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
    }

    private func metadata(
        fileName: String = "sample.md",
        heading: String?,
        isTruncated: Bool = false
    ) -> MarkdownThumbnailMetadata {
        MarkdownThumbnailMetadata(
            fileName: fileName,
            fileExtension: "md",
            heading: heading,
            approximateLineCount: 42,
            isTruncated: isTruncated,
            isUTF8: true
        )
    }
}
