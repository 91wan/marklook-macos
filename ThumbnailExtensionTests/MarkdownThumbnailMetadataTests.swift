import XCTest

final class MarkdownThumbnailMetadataTests: XCTestCase {
    func testExtractsFirstH1() {
        let metadata = parse("# Project Plan\n\nBody")

        XCTAssertEqual(metadata.heading, "Project Plan")
    }

    func testExtractsFirstHeadingAfterUTF8ByteOrderMark() {
        let metadata = parse("\u{FEFF}# Windows Export")

        XCTAssertEqual(metadata.heading, "Windows Export")
        XCTAssertTrue(metadata.isUTF8)
    }

    func testExtractsFirstH2WhenNoH1Exists() {
        let metadata = parse("Intro\n\n## Implementation Notes\n\nBody")

        XCTAssertEqual(metadata.heading, "Implementation Notes")
    }

    func testIgnoresHeadingInsideFencedCode() {
        let metadata = parse("""
        ```swift
        # Not a heading
        ```

        ## Real Heading
        """)

        XCTAssertEqual(metadata.heading, "Real Heading")
    }

    func testIgnoresHeadingInsideTildeFencedCode() {
        let metadata = parse("""
        ~~~markdown
        # Not a heading
        ~~~

        ## Real Heading
        """)

        XCTAssertEqual(metadata.heading, "Real Heading")
    }

    func testTildeFenceRequiresClosingDelimiterAtLeastAsLongAsOpening() {
        let metadata = parse("""
        ~~~~markdown
        # Not a heading
        ~~~
        ## Still inside the fence
        ~~~~

        ## Real Heading
        """)

        XCTAssertEqual(metadata.heading, "Real Heading")
    }

    func testTildeFenceClosingDelimiterMustNotContainInfo() {
        let metadata = parse("""
        ~~~markdown
        # Not a heading
        ~~~not-a-close
        ## Still inside the fence
        ~~~

        ## Real Heading
        """)

        XCTAssertEqual(metadata.heading, "Real Heading")
    }

    func testTrimsAndCollapsesHeadingWhitespace() {
        let metadata = parse("#   A    spaced\t heading   ")

        XCTAssertEqual(metadata.heading, "A spaced heading")
    }

    func testNoHeadingReturnsNilHeading() {
        let metadata = parse("plain text\nwithout headings")

        XCTAssertNil(metadata.heading)
    }

    func testEmptyFileKeepsMetadataSafe() {
        let metadata = parse("")

        XCTAssertNil(metadata.heading)
        XCTAssertEqual(metadata.approximateLineCount, 0)
        XCTAssertFalse(metadata.isTruncated)
        XCTAssertTrue(metadata.isUTF8)
    }

    func testInvalidUTF8DoesNotCrash() {
        let metadata = MarkdownThumbnailMetadata.parsePrefix(
            data: Data([0xFF, 0xFE, 0x0A, 0x23, 0x20, 0x54]),
            fileName: "invalid.md",
            fullFileSize: 6,
            maxPrefixBytes: 64
        )

        XCTAssertNil(metadata.heading)
        XCTAssertEqual(metadata.approximateLineCount, 2)
        XCTAssertFalse(metadata.isTruncated)
        XCTAssertFalse(metadata.isUTF8)
    }

    func testTruncatedPrefixEndingInsideUTF8ScalarKeepsValidMetadata() {
        var data = Data("# 中文标题\n正文".utf8)
        let partialScalar = Array("中".utf8).prefix(2)
        data.append(contentsOf: partialScalar)

        let metadata = MarkdownThumbnailMetadata.parsePrefix(
            data: data,
            fileName: "large.md",
            fullFileSize: data.count + 1,
            maxPrefixBytes: data.count
        )

        XCTAssertEqual(metadata.heading, "中文标题")
        XCTAssertTrue(metadata.isTruncated)
        XCTAssertTrue(metadata.isUTF8)
    }

    func testMarksTruncatedWhenFileSizeExceedsPrefixLimit() {
        let data = Data("# Title\nline 2\nline 3\n".utf8)
        let metadata = MarkdownThumbnailMetadata.parsePrefix(
            data: data,
            fileName: "large.markdown",
            fullFileSize: data.count + 100,
            maxPrefixBytes: data.count
        )

        XCTAssertEqual(metadata.fileName, "large.markdown")
        XCTAssertEqual(metadata.fileExtension, "markdown")
        XCTAssertEqual(metadata.heading, "Title")
        XCTAssertEqual(metadata.approximateLineCount, 3)
        XCTAssertTrue(metadata.isTruncated)
    }

    func testLoadReadsOnlyBoundedPrefix() throws {
        let prefix = "# Prefix Heading\nline 2\n"
        let tail = String(repeating: "tail\n", count: 200) + "# Tail Heading Must Not Win\n"
        let url = try writeTempFile(named: "bounded.md", bytes: Array((prefix + tail).utf8))

        let metadata = try MarkdownThumbnailMetadata.load(from: url, maxPrefixBytes: prefix.utf8.count)

        XCTAssertEqual(metadata.heading, "Prefix Heading")
        XCTAssertEqual(metadata.approximateLineCount, 2)
        XCTAssertTrue(metadata.isTruncated)
    }

    private func parse(_ source: String, fileName: String = "sample.md") -> MarkdownThumbnailMetadata {
        MarkdownThumbnailMetadata.parsePrefix(
            data: Data(source.utf8),
            fileName: fileName,
            fullFileSize: source.utf8.count,
            maxPrefixBytes: 64 * 1024
        )
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
