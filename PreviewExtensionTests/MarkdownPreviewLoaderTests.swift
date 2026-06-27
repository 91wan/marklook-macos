import MarkdownCore
import XCTest

final class MarkdownPreviewLoaderTests: XCTestCase {
    private let loader = MarkdownPreviewLoader()

    func testSmallFileReadsFullContent() throws {
        let url = try writeTempFile(named: "basic.md", bytes: Array("# Title\n\nBody".utf8))

        let document = try loader.loadDocument(from: url)

        XCTAssertEqual(document.source, "# Title\n\nBody")
        XCTAssertEqual(document.sourceByteCount, "# Title\n\nBody".utf8.count)
    }

    func testLargeFileReadsOnlyPrefixAndPreservesOriginalByteCount() throws {
        let options = RenderOptions(
            includeTableOfContents: true,
            fastModeByteThreshold: 64,
            fastModePreviewByteLimit: 32
        )
        let loader = MarkdownPreviewLoader(options: options)
        let bytes = Array("# Heading\n\nPrefix body\n\n".utf8)
            + Array(repeating: UInt8(ascii: "x"), count: 80)
            + Array("\nTAIL_SHOULD_NOT_RENDER".utf8)
        let url = try writeTempFile(named: "large.md", bytes: bytes)

        let document = try loader.loadDocument(from: url)

        XCTAssertEqual(document.sourceByteCount, bytes.count)
        XCTAssertLessThanOrEqual(document.source.utf8.count, options.fastModePreviewByteLimit)
    }

    func testLargeFileTailSentinelDoesNotReachDocumentSource() throws {
        let options = RenderOptions(
            includeTableOfContents: true,
            fastModeByteThreshold: 64,
            fastModePreviewByteLimit: 32
        )
        let loader = MarkdownPreviewLoader(options: options)
        let bytes = Array("# Heading\n\nPrefix body\n\n".utf8)
            + Array(repeating: UInt8(ascii: "x"), count: 80)
            + Array("\nTAIL_SHOULD_NOT_RENDER".utf8)
        let url = try writeTempFile(named: "large-tail.md", bytes: bytes)

        let document = try loader.loadDocument(from: url)

        XCTAssertFalse(document.source.contains("TAIL_SHOULD_NOT_RENDER"))
    }

    func testLargeFileInvalidUTF8InPrefixThrows() throws {
        let options = RenderOptions(
            includeTableOfContents: true,
            fastModeByteThreshold: 4,
            fastModePreviewByteLimit: 8
        )
        let loader = MarkdownPreviewLoader(options: options)
        let url = try writeTempFile(
            named: "invalid-large.md",
            bytes: [0xFF, 0xFE, 0xFD, 0xFC, 0x61, 0x62, 0x63, 0x64, 0x65]
        )

        XCTAssertThrowsError(try loader.loadDocument(from: url)) { error in
            guard case MarkdownPreviewLoader.LoadError.notUTF8(url) = error else {
                return XCTFail("Expected notUTF8, got \(error)")
            }
            XCTAssertEqual(url.lastPathComponent, "invalid-large.md")
        }
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
