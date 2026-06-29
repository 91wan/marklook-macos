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

    private func writeTempFile(named name: String, bytes: [UInt8]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }
}
