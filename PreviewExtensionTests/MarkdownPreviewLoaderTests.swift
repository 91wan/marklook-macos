import XCTest

final class MarkdownPreviewLoaderTests: XCTestCase {
    private let loader = MarkdownPreviewLoader()

    func testLoadsUTF8MarkdownDocument() throws {
        let url = try writeTempFile(named: "basic.md", bytes: Array("# Title\n\nBody".utf8))

        let document = try loader.loadDocument(from: url)

        XCTAssertEqual(document.source, "# Title\n\nBody")
    }

    func testRejectsNonUTF8MarkdownWithoutLossyFallback() throws {
        let url = try writeTempFile(named: "invalid.md", bytes: [0xFF, 0xFE, 0xFD])

        XCTAssertThrowsError(try loader.loadDocument(from: url)) { error in
            guard case MarkdownPreviewLoader.LoadError.notUTF8(url) = error else {
                return XCTFail("Expected notUTF8, got \(error)")
            }
            XCTAssertEqual(url.lastPathComponent, "invalid.md")
        }
    }

    func testRejectsEmptyMarkdownWithClearError() throws {
        let url = try writeTempFile(named: "empty.md", bytes: [])

        XCTAssertThrowsError(try loader.loadDocument(from: url)) { error in
            guard case MarkdownPreviewLoader.LoadError.empty(url) = error else {
                return XCTFail("Expected empty, got \(error)")
            }
            XCTAssertEqual(url.lastPathComponent, "empty.md")
        }
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
