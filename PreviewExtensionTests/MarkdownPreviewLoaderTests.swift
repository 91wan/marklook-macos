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

    func testCachedSmallSizeDoesNotAllowUnboundedReadAfterGrowth() throws {
        let options = RenderOptions(fastModeByteThreshold: 64, fastModePreviewByteLimit: 32)
        let url = try writeTempFile(named: "grown.md", bytes: Array("# Seed\n".utf8))
        XCTAssertEqual(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, 7)

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((String(repeating: "x", count: 80) + "\nTAIL_SHOULD_NOT_RENDER").utf8))
        try handle.close()

        XCTAssertEqual(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, 7)
        XCTAssertEqual(try URL(fileURLWithPath: url.path).resourceValues(forKeys: [.fileSizeKey]).fileSize, 110)
        let document = try MarkdownPreviewLoader(options: options).loadDocument(from: url)

        XCTAssertLessThanOrEqual(document.source.utf8.count, 32)
        XCTAssertFalse(document.source.contains("TAIL_SHOULD_NOT_RENDER"))
        XCTAssertEqual(document.sourceByteCount, 65)
    }

    func testThresholdEqualityReadsFullFileAndOneOverUsesPrefix() throws {
        let options = RenderOptions(fastModeByteThreshold: 64, fastModePreviewByteLimit: 32)
        let loader = MarkdownPreviewLoader(options: options)

        for byteCount in [64, 65] {
            let source = String(repeating: "x", count: byteCount)
            let url = try writeTempFile(named: "boundary.md", bytes: Array(source.utf8))
            let document = try loader.loadDocument(from: url)

            XCTAssertEqual(document.source, String(source.prefix(byteCount == 64 ? 64 : 32)))
            XCTAssertEqual(document.sourceByteCount, byteCount)
        }
    }

    func testCachedZeroSizeDoesNotHideNewContent() throws {
        let url = try writeTempFile(named: "was-empty.md", bytes: [])
        XCTAssertEqual(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, 0)
        let source = "# Current\n"
        try overwriteFile(at: url, bytes: Array(source.utf8))
        XCTAssertEqual(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, 0)

        let document = try loader.loadDocument(from: url)

        XCTAssertEqual(document.source, source)
        XCTAssertEqual(document.sourceByteCount, source.utf8.count)
    }

    func testCachedLargeSizeDoesNotForceFastModeAfterShrink() throws {
        let options = RenderOptions(fastModeByteThreshold: 64, fastModePreviewByteLimit: 32)
        let url = try writeTempFile(named: "shrunk.md", bytes: Array(repeating: 0x78, count: 128))
        XCTAssertEqual(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, 128)
        let source = "# Small\n"
        try overwriteFile(at: url, bytes: Array(source.utf8))
        XCTAssertEqual(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, 128)

        let document = try MarkdownPreviewLoader(options: options).loadDocument(from: url)

        XCTAssertEqual(document.source, source)
        XCTAssertEqual(document.sourceByteCount, source.utf8.count)
    }

    func testPrefixLimitMayExceedThreshold() throws {
        let options = RenderOptions(fastModeByteThreshold: 4, fastModePreviewByteLimit: 8)
        let url = try writeTempFile(named: "wide-prefix.md", bytes: Array("abcdefghijkl".utf8))

        let document = try MarkdownPreviewLoader(options: options).loadDocument(from: url)

        XCTAssertEqual(document.source, "abcdefgh")
        XCTAssertEqual(document.sourceByteCount, 12)
    }

    func testFastPrefixTrimsOnlyIncompleteUTF8Boundary() throws {
        let options = RenderOptions(fastModeByteThreshold: 4, fastModePreviewByteLimit: 6)
        let source = "# \u{6807}\u{9898}\nBody"
        let url = try writeTempFile(named: "utf8-boundary.md", bytes: Array(source.utf8))

        let document = try MarkdownPreviewLoader(options: options).loadDocument(from: url)

        XCTAssertEqual(document.source, "# \u{6807}")
        XCTAssertEqual(document.sourceByteCount, source.utf8.count)
    }

    func testInvalidUTF8OutsideFastPrefixIsNotDecoded() throws {
        let options = RenderOptions(fastModeByteThreshold: 8, fastModePreviewByteLimit: 4)
        let bytes = Array("head".utf8) + [0xFF] + Array("tail".utf8)
        let url = try writeTempFile(named: "invalid-tail.md", bytes: bytes)

        let document = try MarkdownPreviewLoader(options: options).loadDocument(from: url)

        XCTAssertEqual(document.source, "head")
        XCTAssertEqual(document.sourceByteCount, bytes.count)
    }

    func testSmallFileDoesNotTrimIncompleteUTF8Tail() throws {
        let url = try writeTempFile(named: "incomplete.md", bytes: [0x61, 0xE2, 0x82])

        XCTAssertThrowsError(try loader.loadDocument(from: url)) { error in
            XCTAssertEqual(error as? MarkdownPreviewLoader.LoadError, .notUTF8(url))
        }
    }

    func testMissingFileReportsUnreadable() throws {
        let url = try writeTempFile(named: "missing.md", bytes: Array("body".utf8))
        try FileManager.default.removeItem(at: url)

        XCTAssertThrowsError(try loader.loadDocument(from: url)) { error in
            guard case let MarkdownPreviewLoader.LoadError.unreadable(failedURL, _) = error else {
                return XCTFail("Expected unreadable, got \(error)")
            }
            XCTAssertEqual(failedURL, url)
        }
    }

    func testRejectsNegativeAndOverflowingReadLimits() throws {
        let url = try writeTempFile(named: "limits.md", bytes: Array("body".utf8))
        for (threshold, prefix) in [(-1, 4), (4, -1), (Int.max, 4)] {
            let options = RenderOptions(fastModeByteThreshold: threshold, fastModePreviewByteLimit: prefix)

            XCTAssertThrowsError(try MarkdownPreviewLoader(options: options).loadDocument(from: url)) { error in
                XCTAssertEqual(
                    error as? MarkdownPreviewLoader.LoadError,
                    .unreadable(url, "Preview byte limits are invalid.")
                )
            }
        }
    }

    func testZeroPrefixOnlyRejectsFastDocuments() throws {
        let options = RenderOptions(fastModeByteThreshold: 4, fastModePreviewByteLimit: 0)
        let loader = MarkdownPreviewLoader(options: options)
        let smallURL = try writeTempFile(named: "small-zero-prefix.md", bytes: Array("abc".utf8))
        let largeURL = try writeTempFile(named: "large-zero-prefix.md", bytes: Array("abcde".utf8))

        XCTAssertEqual(try loader.loadDocument(from: smallURL).source, "abc")
        XCTAssertThrowsError(try loader.loadDocument(from: largeURL)) { error in
            XCTAssertEqual(error as? MarkdownPreviewLoader.LoadError, .empty(largeURL))
        }
    }

    func testZeroThresholdReadsPrefixForNonemptyFile() throws {
        let options = RenderOptions(fastModeByteThreshold: 0, fastModePreviewByteLimit: 4)
        let url = try writeTempFile(named: "zero-threshold.md", bytes: Array("abcdef".utf8))

        let document = try MarkdownPreviewLoader(options: options).loadDocument(from: url)

        XCTAssertEqual(document.source, "abcd")
        XCTAssertEqual(document.sourceByteCount, 6)
    }

    func testFullReadAccumulatesMultipleBoundedChunks() throws {
        let options = RenderOptions(fastModeByteThreshold: 80_000, fastModePreviewByteLimit: 32)
        let source = String(repeating: "x", count: 70_000)
        let url = try writeTempFile(named: "multiple-chunks.md", bytes: Array(source.utf8))

        let document = try MarkdownPreviewLoader(options: options).loadDocument(from: url)

        XCTAssertEqual(document.source, source)
        XCTAssertEqual(document.sourceByteCount, 70_000)
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

    private func overwriteFile(at url: URL, bytes: [UInt8]) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: Data(bytes))
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
