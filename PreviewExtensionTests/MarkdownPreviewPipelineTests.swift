import MarkdownCore
import XCTest

final class MarkdownPreviewPipelineTests: XCTestCase {
    func testValidMarkdownReturnsHTMLDocumentPreview() throws {
        let url = try writeTempFile(named: "valid.md", bytes: Array("# Title\n\nBody".utf8))
        let pipeline = MarkdownPreviewPipeline()

        let preview = pipeline.preview(for: url)

        guard case let .htmlDocument(html) = preview else {
            return XCTFail("Expected HTML document preview, got \(preview)")
        }
        XCTAssertTrue(html.contains("<h1 id=\"title\">Title</h1>"))
        XCTAssertTrue(html.contains("Body"))
    }

    func testLoaderErrorReturnsLocalErrorPreview() throws {
        let url = try writeTempFile(named: "invalid.md", bytes: [0xFF, 0xFE, 0xFD])
        let pipeline = MarkdownPreviewPipeline()

        let preview = pipeline.preview(for: url)

        guard case let .error(title, message) = preview else {
            return XCTFail("Expected local error preview, got \(preview)")
        }
        XCTAssertEqual(title, "Preview unavailable")
        XCTAssertTrue(message.contains("not encoded as UTF-8"))
    }

    func testDiagnosticEventsRecordLoadAndRenderSuccess() throws {
        let url = try writeTempFile(named: "valid.md", bytes: Array("# Title\n".utf8))
        let pipeline = MarkdownPreviewPipeline()
        var events: [MarkdownPreviewPipeline.Event] = []

        _ = pipeline.preview(for: url) { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.loadedDocument, .renderedHTML])
    }

    func testMissingFileErrorHTMLUsesControlledMessage() throws {
        let url = try writeTempFile(named: "private-missing.md", bytes: Array("body".utf8))
        try FileManager.default.removeItem(at: url)

        assertControlledErrorHTML(
            MarkdownPreviewPipeline().preview(for: url),
            message: "Could not read this file.",
            url: url
        )
    }

    func testEmptyFileErrorHTMLUsesControlledMessage() throws {
        let url = try writeTempFile(named: "private-empty.md", bytes: [])

        assertControlledErrorHTML(
            MarkdownPreviewPipeline().preview(for: url),
            message: "This file is empty.",
            url: url
        )
    }

    func testNonUTF8FileErrorHTMLUsesControlledMessage() throws {
        let url = try writeTempFile(named: "private-invalid.md", bytes: [0xFF, 0xFE, 0xFD])

        assertControlledErrorHTML(
            MarkdownPreviewPipeline().preview(for: url),
            message: "This file is not encoded as UTF-8.",
            url: url
        )
    }

    func testRendererLocalizedErrorHTMLUsesFixedFallback() throws {
        let url = try writeTempFile(named: "private-renderer.md", bytes: Array("# Valid\n".utf8))
        let rawReason = "PRIVATE_RENDERER_REASON: \(url.lastPathComponent) at \(url.path)"
        let pipeline = MarkdownPreviewPipeline(
            renderer: MarkdownPreviewRenderer(renderer: FailingRenderer(message: rawReason))
        )
        var events: [MarkdownPreviewPipeline.Event] = []

        let preview = pipeline.preview(for: url) { events.append($0) }

        assertControlledErrorHTML(preview, message: "Could not create this preview.", url: url)
        guard case let .error(title, message) = preview else { return }
        let html = PreviewErrorHTMLDocument.html(title: title, message: message)
        XCTAssertFalse(message.contains("PRIVATE_RENDERER_REASON"))
        XCTAssertFalse(html.contains("PRIVATE_RENDERER_REASON"))
        XCTAssertEqual(events, [.loadedDocument])
    }

    private func assertControlledErrorHTML(
        _ preview: MarkdownPreviewContent,
        message expectedMessage: String,
        url: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .error(title, message) = preview else {
            return XCTFail("Expected error preview, got \(preview)", file: file, line: line)
        }
        let html = PreviewErrorHTMLDocument.html(title: title, message: message)
        XCTAssertEqual(title, "Preview unavailable", file: file, line: line)
        XCTAssertEqual(message, expectedMessage, file: file, line: line)
        XCTAssertTrue(html.contains("<p>\(expectedMessage)</p>"), file: file, line: line)
        XCTAssertFalse(message.contains(url.lastPathComponent), file: file, line: line)
        XCTAssertFalse(html.contains(url.lastPathComponent), file: file, line: line)
        XCTAssertFalse(html.contains(url.path), file: file, line: line)
    }

    private struct FailingRenderer: MarkdownRendering {
        let message: String

        func render(_ document: MarkdownDocument, options: RenderOptions) throws -> RenderResult {
            throw RendererError(message: message)
        }
    }

    private struct RendererError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private func writeTempFile(named name: String, bytes: [UInt8]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: directory)
        }
        let url = directory.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }
}
