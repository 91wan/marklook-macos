import Foundation

struct MarkdownThumbnailMetadata: Equatable, Sendable {
    static let defaultMaxPrefixBytes = 64 * 1024

    let fileName: String
    let fileExtension: String
    let heading: String?
    let approximateLineCount: Int
    let isTruncated: Bool
    let isUTF8: Bool

    static func load(
        from url: URL,
        maxPrefixBytes: Int = defaultMaxPrefixBytes
    ) throws -> MarkdownThumbnailMetadata {
        let fileSize = try fileSizeForThumbnail(at: url)
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        let boundedCount = max(0, maxPrefixBytes)
        let data = try handle.read(upToCount: boundedCount) ?? Data()
        return parsePrefix(
            data: data,
            fileName: url.lastPathComponent,
            fullFileSize: fileSize,
            maxPrefixBytes: boundedCount
        )
    }

    static func parsePrefix(
        data: Data,
        fileName: String,
        fullFileSize: Int,
        maxPrefixBytes: Int
    ) -> MarkdownThumbnailMetadata {
        let fileExtension = (fileName as NSString).pathExtension
        let isTruncated = fullFileSize > data.count || fullFileSize > maxPrefixBytes
        let lineCount = approximateLineCount(in: data)

        guard let source = UTF8PrefixDecoder.decode(data) else {
            return MarkdownThumbnailMetadata(
                fileName: fileName,
                fileExtension: fileExtension,
                heading: nil,
                approximateLineCount: lineCount,
                isTruncated: isTruncated,
                isUTF8: false
            )
        }

        return MarkdownThumbnailMetadata(
            fileName: fileName,
            fileExtension: fileExtension,
            heading: firstHeading(in: source),
            approximateLineCount: lineCount,
            isTruncated: isTruncated,
            isUTF8: true
        )
    }

    private static func fileSizeForThumbnail(at url: URL) throws -> Int {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return values.fileSize ?? 0
    }

    private static func approximateLineCount(in data: Data) -> Int {
        guard !data.isEmpty else {
            return 0
        }

        let newlineCount = data.reduce(0) { count, byte in
            byte == UInt8(ascii: "\n") ? count + 1 : count
        }

        if data.last == UInt8(ascii: "\n") {
            return newlineCount
        }

        return newlineCount + 1
    }

    private static func firstHeading(in source: String) -> String? {
        var isInsideFence = false
        var fenceMarker: Character?

        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if let marker = fenceDelimiter(in: trimmedLine) {
                if isInsideFence {
                    if marker == fenceMarker {
                        isInsideFence = false
                        fenceMarker = nil
                    }
                } else {
                    isInsideFence = true
                    fenceMarker = marker
                }
                continue
            }

            guard !isInsideFence, let heading = headingText(in: trimmedLine) else {
                continue
            }

            return heading
        }

        return nil
    }

    private static func fenceDelimiter(in line: String) -> Character? {
        if line.hasPrefix("```") {
            return "`"
        }
        if line.hasPrefix("~~~") {
            return "~"
        }
        return nil
    }

    private static func headingText(in line: String) -> String? {
        let headingPrefix: String
        if line.hasPrefix("# ") {
            headingPrefix = "# "
        } else if line.hasPrefix("## ") {
            headingPrefix = "## "
        } else {
            return nil
        }

        let rawHeading = String(line.dropFirst(headingPrefix.count))
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .trimmingCharacters(in: .whitespaces)

        let collapsed = rawHeading
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return collapsed.isEmpty ? nil : collapsed
    }
}
