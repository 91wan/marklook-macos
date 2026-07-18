import Foundation

public struct RenderOptions: Equatable, Sendable {
    public let includeTableOfContents: Bool
    public let fastModeByteThreshold: Int
    public let fastModePreviewByteLimit: Int

    public init(
        includeTableOfContents: Bool = true,
        fastModeByteThreshold: Int = 1_000_000,
        fastModePreviewByteLimit: Int = 80_000
    ) {
        self.includeTableOfContents = includeTableOfContents
        self.fastModeByteThreshold = fastModeByteThreshold
        self.fastModePreviewByteLimit = fastModePreviewByteLimit
    }
}

public struct RenderResult: Equatable, Sendable {
    public let html: String
    public let tableOfContents: [TableOfContents.Item]
    public let frontMatter: FrontMatter?
    public let diagnostics: [RenderDiagnostic]
    public let usedFastMode: Bool
    public let sourceByteCount: Int

    public init(
        html: String,
        tableOfContents: [TableOfContents.Item],
        frontMatter: FrontMatter?,
        diagnostics: [RenderDiagnostic],
        usedFastMode: Bool,
        sourceByteCount: Int
    ) {
        self.html = html
        self.tableOfContents = tableOfContents
        self.frontMatter = frontMatter
        self.diagnostics = diagnostics
        self.usedFastMode = usedFastMode
        self.sourceByteCount = sourceByteCount
    }
}

public protocol MarkdownRendering {
    func render(_ document: MarkdownDocument, options: RenderOptions) throws -> RenderResult
}

public extension MarkdownRendering {
    func render(_ document: MarkdownDocument) throws -> RenderResult {
        try render(document, options: RenderOptions())
    }
}

public struct MarkdownRenderer: MarkdownRendering, Sendable {
    private let builder: HTMLDocumentBuilder

    public init() {
        self.builder = HTMLDocumentBuilder()
    }

    public func render(_ document: MarkdownDocument, options: RenderOptions = RenderOptions()) throws -> RenderResult {
        if document.sourceByteCount > options.fastModeByteThreshold {
            return renderFast(document, options: options)
        }

        return renderFull(document, options: options)
    }

    private func renderFull(_ document: MarkdownDocument, options: RenderOptions) -> RenderResult {
        var renderer = BlockRenderer(options: options)
        let bodyHTML = renderer.render(document.source)

        return RenderResult(
            html: builder.build(title: title(for: document, renderer: renderer), trustedBodyHTML: bodyHTML),
            tableOfContents: renderer.tableOfContents,
            frontMatter: document.frontMatter,
            diagnostics: renderer.diagnostics,
            usedFastMode: false,
            sourceByteCount: document.sourceByteCount
        )
    }

    private func renderFast(_ document: MarkdownDocument, options: RenderOptions) -> RenderResult {
        let previewSource = Self.utf8SafePrefix(document.source, byteLimit: options.fastModePreviewByteLimit)
        var renderer = BlockRenderer(options: options)
        let bodyHTML = renderer.render(previewSource)
        renderer.diagnostics.append(RenderDiagnostic(kind: .fastMode, message: "Document exceeded fast mode threshold."))
        let warningHTML = "<p class=\"render-warning\">Fast mode: document truncated for Quick Look responsiveness.</p>"

        return RenderResult(
            html: builder.build(title: title(for: document, renderer: renderer), trustedBodyHTML: "\(warningHTML)\n\(bodyHTML)"),
            tableOfContents: renderer.tableOfContents,
            frontMatter: document.frontMatter,
            diagnostics: renderer.diagnostics,
            usedFastMode: true,
            sourceByteCount: document.sourceByteCount
        )
    }

    private func title(for document: MarkdownDocument, renderer: BlockRenderer) -> String {
        document.frontMatter?.fields["title"] ?? renderer.tableOfContents.first?.title ?? "MarkLook"
    }

    private static func utf8SafePrefix(_ source: String, byteLimit: Int) -> String {
        guard byteLimit > 0 else {
            return ""
        }

        var bytes = Array(source.utf8.prefix(byteLimit))
        while !bytes.isEmpty {
            if let prefix = String(bytes: bytes, encoding: .utf8) {
                return prefix
            }
            bytes.removeLast()
        }

        return ""
    }
}

private struct BlockRenderer {
    private struct ListItem {
        let indent: Int
        let ordered: Bool
        let content: String
    }

    private enum InlineDelimiter: String {
        case emphasis = "*"
        case strong = "**"
        case strikethrough = "~~"

        var openingTag: String {
            switch self {
            case .emphasis: "<em>"
            case .strong: "<strong>"
            case .strikethrough: "<del>"
            }
        }

        var closingTag: String {
            switch self {
            case .emphasis: "</em>"
            case .strong: "</strong>"
            case .strikethrough: "</del>"
            }
        }

        var width: Int {
            rawValue.count
        }
    }

    private enum InlinePiece {
        case text(String)
        case html(String)
    }

    private struct OpenDelimiter {
        let delimiter: InlineDelimiter
        let pieceIndex: Int
    }

    let options: RenderOptions
    var diagnostics: [RenderDiagnostic] = []
    var tableOfContents: [TableOfContents.Item] = []

    private var slugCounts: [String: Int] = [:]

    init(options: RenderOptions) {
        self.options = options
    }

    mutating func render(_ source: String) -> String {
        let normalizedSource = source.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalizedSource.components(separatedBy: "\n")
        var blocks: [String] = []
        var index = 0

        while index < lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            if isFenceStart(lines[index]) {
                let rendered = renderFencedCode(lines: lines, startIndex: index)
                blocks.append(rendered.html)
                index = rendered.nextIndex
                continue
            }

            if let table = renderTable(lines: lines, startIndex: index) {
                blocks.append(table.html)
                index = table.nextIndex
                continue
            }

            if let heading = parseHeading(lines[index]) {
                blocks.append(renderHeading(heading))
                index += 1
                continue
            }

            if isHorizontalRule(lines[index]) {
                blocks.append("<hr>")
                index += 1
                continue
            }

            if isBlockquote(lines[index]) {
                let rendered = renderBlockquote(lines: lines, startIndex: index)
                blocks.append(rendered.html)
                index = rendered.nextIndex
                continue
            }

            if parseListItem(lines[index]) != nil {
                let rendered = renderList(lines: lines, startIndex: index)
                blocks.append(rendered.html)
                index = rendered.nextIndex
                continue
            }

            let rendered = renderParagraph(lines: lines, startIndex: index)
            blocks.append(rendered.html)
            index = rendered.nextIndex
        }

        return blocks.joined(separator: "\n")
    }

    private mutating func renderHeading(_ heading: (level: Int, title: String)) -> String {
        let id = TableOfContents.uniqueSlug(for: heading.title, counts: &slugCounts)
        if options.includeTableOfContents, heading.level <= 3 {
            tableOfContents.append(TableOfContents.Item(title: heading.title, level: heading.level, id: id))
        }

        return "<h\(heading.level) id=\"\(ResourcePolicy.escapeAttribute(id))\">\(renderInline(heading.title))</h\(heading.level)>"
    }

    private mutating func renderFencedCode(lines: [String], startIndex: Int) -> (html: String, nextIndex: Int) {
        let opening = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let info = String(opening.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var codeLines: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            if isFenceStart(lines[index]) {
                index += 1
                break
            }

            codeLines.append(lines[index])
            index += 1
        }

        let languageClass = sanitizedLanguageClass(info)
        let classAttribute = languageClass.isEmpty ? "" : " class=\"language-\(languageClass)\""
        return ("<pre><code\(classAttribute)>\(ResourcePolicy.escapeHTML(codeLines.joined(separator: "\n")))</code></pre>", index)
    }

    private mutating func renderTable(lines: [String], startIndex: Int) -> (html: String, nextIndex: Int)? {
        guard startIndex + 1 < lines.count,
              let headers = parseTableRow(lines[startIndex]),
              let separator = parseTableRow(lines[startIndex + 1]),
              isTableSeparator(separator) else {
            return nil
        }

        var rows: [[String]] = []
        var index = startIndex + 2

        while index < lines.count, let row = parseTableRow(lines[index]) {
            rows.append(row)
            index += 1
        }

        let headerHTML = headers
            .map { "<th>\(renderInline($0))</th>" }
            .joined()
        let bodyHTML = rows
            .map { row in
                let cells = row.map { "<td>\(renderInline($0))</td>" }.joined()
                return "<tr>\(cells)</tr>"
            }
            .joined(separator: "\n")

        return (
            """
            <table>
            <thead><tr>\(headerHTML)</tr></thead>
            <tbody>
            \(bodyHTML)
            </tbody>
            </table>
            """,
            index
        )
    }

    private mutating func renderBlockquote(lines: [String], startIndex: Int) -> (html: String, nextIndex: Int) {
        var parts: [String] = []
        var index = startIndex

        while index < lines.count, isBlockquote(lines[index]) {
            var line = lines[index].trimmingCharacters(in: .whitespaces)
            line.removeFirst()
            if line.first == " " {
                line.removeFirst()
            }
            parts.append(line)
            index += 1
        }

        return ("<blockquote>\n<p>\(renderInline(parts.joined(separator: " ")))</p>\n</blockquote>", index)
    }

    private mutating func renderList(lines: [String], startIndex: Int) -> (html: String, nextIndex: Int) {
        guard let firstItem = parseListItem(lines[startIndex]) else {
            return ("", startIndex)
        }

        var index = startIndex
        let html = renderListLevel(
            lines: lines,
            index: &index,
            indent: firstItem.indent,
            ordered: firstItem.ordered
        )
        return (html, index)
    }

    private mutating func renderListLevel(
        lines: [String],
        index: inout Int,
        indent: Int,
        ordered: Bool
    ) -> String {
        var items: [String] = []

        while index < lines.count {
            guard let item = parseListItem(lines[index]),
                  item.indent == indent,
                  item.ordered == ordered else {
                break
            }

            var itemHTML = "<li>\(renderListItemContent(item.content))"
            var hasNestedList = false
            index += 1

            while index < lines.count,
                  let child = parseListItem(lines[index]),
                  child.indent > indent {
                hasNestedList = true
                itemHTML += "\n" + renderListLevel(
                    lines: lines,
                    index: &index,
                    indent: child.indent,
                    ordered: child.ordered
                )
            }

            itemHTML += hasNestedList ? "\n</li>" : "</li>"
            items.append(itemHTML)
        }

        let tag = ordered ? "ol" : "ul"
        return "<\(tag)>\n\(items.joined(separator: "\n"))\n</\(tag)>"
    }

    private mutating func renderListItemContent(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("[x] ") || trimmed.hasPrefix("[X] ") {
            let task = String(trimmed.dropFirst(4))
            return "<input type=\"checkbox\" checked disabled> \(renderInline(task))"
        }

        if trimmed.hasPrefix("[ ] ") {
            let task = String(trimmed.dropFirst(4))
            return "<input type=\"checkbox\" disabled> \(renderInline(task))"
        }

        return renderInline(content)
    }

    private mutating func renderParagraph(lines: [String], startIndex: Int) -> (html: String, nextIndex: Int) {
        var parts: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }

            if !parts.isEmpty, startsBlock(line, lines: lines, index: index) {
                break
            }

            parts.append(line.trimmingCharacters(in: .whitespaces))
            index += 1
        }

        return ("<p>\(renderInline(parts.joined(separator: " ")))</p>", index)
    }

    private mutating func renderInline(_ text: String) -> String {
        let policy = ResourcePolicy()
        var output = ""
        var buffer = ""
        var cursor = text.startIndex

        func flushBuffer() {
            guard !buffer.isEmpty else {
                return
            }
            output += renderTextMarkup(buffer, policy: policy)
            buffer.removeAll(keepingCapacity: true)
        }

        while cursor < text.endIndex {
            if text[cursor] == "`",
               let closing = text[text.index(after: cursor)...].firstIndex(of: "`") {
                flushBuffer()
                let codeStart = text.index(after: cursor)
                output += "<code>\(ResourcePolicy.escapeHTML(String(text[codeStart..<closing])))</code>"
                cursor = text.index(after: closing)
                continue
            }

            if text[cursor] == "!",
               let image = parseImage(in: text, at: cursor) {
                flushBuffer()
                output += policy.renderImage(alt: image.alt, url: image.url, diagnostics: &diagnostics)
                cursor = image.nextIndex
                continue
            }

            if text[cursor] == "[",
               let link = parseLink(in: text, at: cursor) {
                flushBuffer()
                let labelHTML = renderTextMarkup(link.label, policy: policy)
                output += policy.renderLink(labelHTML: labelHTML, url: link.url, diagnostics: &diagnostics)
                cursor = link.nextIndex
                continue
            }

            buffer.append(text[cursor])
            cursor = text.index(after: cursor)
        }

        flushBuffer()
        return output
    }

    private mutating func renderTextMarkup(_ text: String, policy: ResourcePolicy) -> String {
        var pieces: [InlinePiece] = []
        var openDelimiters: [OpenDelimiter] = []
        var buffer = ""
        var cursor = text.startIndex

        func flushBuffer() {
            guard !buffer.isEmpty else {
                return
            }
            pieces.append(.text(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        func open(_ delimiter: InlineDelimiter) {
            pieces.append(.text(delimiter.rawValue))
            openDelimiters.append(OpenDelimiter(delimiter: delimiter, pieceIndex: pieces.count - 1))
        }

        func close(_ delimiter: InlineDelimiter) {
            let opener = openDelimiters.removeLast()
            pieces[opener.pieceIndex] = .html(delimiter.openingTag)
            pieces.append(.html(delimiter.closingTag))
        }

        while cursor < text.endIndex {
            let marker = text[cursor]
            guard marker == "*" || marker == "~" else {
                buffer.append(marker)
                cursor = text.index(after: cursor)
                continue
            }

            let runStart = cursor
            while cursor < text.endIndex, text[cursor] == marker {
                cursor = text.index(after: cursor)
            }

            var remaining = text.distance(from: runStart, to: cursor)
            if marker == "~", remaining < InlineDelimiter.strikethrough.width {
                buffer.append(contentsOf: String(repeating: "~", count: remaining))
                continue
            }

            flushBuffer()
            let previous = runStart > text.startIndex ? text[text.index(before: runStart)] : nil
            let next = cursor < text.endIndex ? text[cursor] : nil
            let canClose = previous.map { !$0.isWhitespace } ?? false
            let canOpen = next.map { !$0.isWhitespace } ?? false

            if canClose {
                while let opener = openDelimiters.last,
                      opener.delimiter.rawValue.first == marker,
                      opener.delimiter.width <= remaining {
                    close(opener.delimiter)
                    remaining -= opener.delimiter.width
                }
            }

            if canOpen {
                let doubleDelimiter: InlineDelimiter = marker == "*" ? .strong : .strikethrough
                while remaining >= doubleDelimiter.width {
                    open(doubleDelimiter)
                    remaining -= doubleDelimiter.width
                }
                if marker == "*", remaining == InlineDelimiter.emphasis.width {
                    open(.emphasis)
                    remaining = 0
                }
            }

            if remaining > 0 {
                pieces.append(.text(String(repeating: String(marker), count: remaining)))
            }
        }

        flushBuffer()

        var output = ""
        for piece in pieces {
            switch piece {
            case let .text(value):
                output += policy.sanitizeText(value, diagnostics: &diagnostics)
            case let .html(value):
                output += value
            }
        }
        return output
    }

    private func startsBlock(_ line: String, lines: [String], index: Int) -> Bool {
        isFenceStart(line)
            || parseHeading(line) != nil
            || isHorizontalRule(line)
            || isBlockquote(line)
            || parseUnorderedListItem(line) != nil
            || parseOrderedListItem(line) != nil
            || (index + 1 < lines.count && parseTableRow(line) != nil && parseTableRow(lines[index + 1]).map(isTableSeparator) == true)
    }

    private func parseHeading(_ line: String) -> (level: Int, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var level = 0
        var cursor = trimmed.startIndex

        while cursor < trimmed.endIndex, trimmed[cursor] == "#", level < 6 {
            level += 1
            cursor = trimmed.index(after: cursor)
        }

        guard level > 0, cursor < trimmed.endIndex, trimmed[cursor] == " " else {
            return nil
        }

        let title = String(trimmed[trimmed.index(after: cursor)...]).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else {
            return nil
        }

        return (level, title)
    }

    private func isFenceStart(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("```")
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            return false
        }
        return trimmed.allSatisfy { $0 == "-" } || trimmed.allSatisfy { $0 == "*" } || trimmed.allSatisfy { $0 == "_" }
    }

    private func isBlockquote(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private func parseUnorderedListItem(_ line: String) -> String? {
        guard let item = parseListItem(line), !item.ordered else {
            return nil
        }
        return item.content
    }

    private func parseOrderedListItem(_ line: String) -> String? {
        guard let item = parseListItem(line), item.ordered else {
            return nil
        }
        return item.content
    }

    private func parseListItem(_ line: String) -> ListItem? {
        var indent = 0
        var cursor = line.startIndex

        while cursor < line.endIndex {
            if line[cursor] == " " {
                indent += 1
            } else if line[cursor] == "\t" {
                indent += 4
            } else {
                break
            }
            cursor = line.index(after: cursor)
        }

        let body = String(line[cursor...])
        for marker in ["- ", "* ", "+ "] where body.hasPrefix(marker) {
            return ListItem(
                indent: indent,
                ordered: false,
                content: String(body.dropFirst(marker.count))
            )
        }

        guard let markerRange = body.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) else {
            return nil
        }

        return ListItem(
            indent: indent,
            ordered: true,
            content: String(body[markerRange.upperBound...])
        )
    }

    private func parseTableRow(_ line: String) -> [String]? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else {
            return nil
        }

        if trimmed.first == "|" {
            trimmed.removeFirst()
        }
        if trimmed.last == "|" {
            trimmed.removeLast()
        }

        let cells = trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        return cells.count > 1 ? cells : nil
    }

    private func isTableSeparator(_ cells: [String]) -> Bool {
        cells.allSatisfy { cell in
            let marker = cell
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ":", with: "")
            return marker.count >= 3 && marker.allSatisfy { $0 == "-" }
        }
    }

    private func parseImage(in text: String, at index: String.Index) -> (alt: String, url: String, nextIndex: String.Index)? {
        let bracketStart = text.index(after: index)
        guard bracketStart < text.endIndex, text[bracketStart] == "[" else {
            return nil
        }

        guard let parsed = parseBracketedTarget(in: text, labelStart: text.index(after: bracketStart)) else {
            return nil
        }

        return (parsed.label, parsed.url, parsed.nextIndex)
    }

    private func parseLink(in text: String, at index: String.Index) -> (label: String, url: String, nextIndex: String.Index)? {
        parseBracketedTarget(in: text, labelStart: text.index(after: index))
    }

    private func parseBracketedTarget(
        in text: String,
        labelStart: String.Index
    ) -> (label: String, url: String, nextIndex: String.Index)? {
        guard let labelEnd = text[labelStart...].firstIndex(of: "]") else {
            return nil
        }

        let parenthesisStart = text.index(after: labelEnd)
        guard parenthesisStart < text.endIndex, text[parenthesisStart] == "(" else {
            return nil
        }

        let urlStart = text.index(after: parenthesisStart)
        guard let urlEnd = closingParenthesis(in: text, from: urlStart) else {
            return nil
        }

        return (
            String(text[labelStart..<labelEnd]),
            String(text[urlStart..<urlEnd]),
            text.index(after: urlEnd)
        )
    }

    private func closingParenthesis(in text: String, from start: String.Index) -> String.Index? {
        var depth = 0
        var cursor = start

        while cursor < text.endIndex {
            if text[cursor] == "(" {
                depth += 1
            } else if text[cursor] == ")" {
                if depth == 0 {
                    return cursor
                }
                depth -= 1
            }
            cursor = text.index(after: cursor)
        }

        return nil
    }

    private func sanitizedLanguageClass(_ info: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = info.unicodeScalars.prefix { allowed.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }
}
