import MarkdownCore
import XCTest

final class MarkdownPreviewRenderingTests: XCTestCase {
    func testRendererProducesSafeHTMLForPreview() throws {
        let renderer = MarkdownPreviewRenderer()
        let document = MarkdownDocument(source: """
        # Preview
        <script>alert(1)</script>
        ![remote](https://example.com/a.png)
        [site](https://example.com)
        """)

        let result = try renderer.render(document)

        XCTAssertTrue(result.html.contains("<h1 id=\"preview\">Preview</h1>"))
        XCTAssertFalse(result.html.localizedCaseInsensitiveContains("<script"))
        XCTAssertFalse(result.html.contains("href=\"https://"))
        XCTAssertFalse(result.html.contains("src=\"https://"))
        XCTAssertTrue(result.html.contains("Remote image blocked"))
    }

    func testRendererUsesQuickLookFastModeDefaults() throws {
        let renderer = MarkdownPreviewRenderer()
        let source = String(repeating: "a", count: 1_000_001)

        let result = try renderer.render(MarkdownDocument(source: source))

        XCTAssertTrue(result.usedFastMode)
        XCTAssertEqual(result.sourceByteCount, 1_000_001)
        XCTAssertLessThan(result.html.utf8.count, source.utf8.count)
    }

    func testLoaderAndRendererTogetherUseFastModeForLargeFile() throws {
        let options = RenderOptions(
            includeTableOfContents: true,
            fastModeByteThreshold: 64,
            fastModePreviewByteLimit: 32
        )
        let loader = MarkdownPreviewLoader(options: options)
        let renderer = MarkdownPreviewRenderer(options: options)
        let bytes = Array("# Heading\n\nPrefix body\n\n".utf8)
            + Array(repeating: UInt8(ascii: "x"), count: 80)
            + Array("\nTAIL_SHOULD_NOT_RENDER".utf8)
        let url = try writeTempFile(named: "large-render.md", bytes: bytes)

        let document = try loader.loadDocument(from: url)
        let result = try renderer.render(document)

        XCTAssertTrue(result.usedFastMode)
        XCTAssertEqual(result.sourceByteCount, bytes.count)
        XCTAssertFalse(result.html.contains("TAIL_SHOULD_NOT_RENDER"))
        XCTAssertTrue(result.html.contains("Fast mode: document truncated for Quick Look responsiveness."))
    }

    private func writeTempFile(named name: String, bytes: [UInt8]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }
}
