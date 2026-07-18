import Foundation
import MarkdownCore

struct MarkdownPreviewLoader {
    private let options: RenderOptions

    enum LoadError: LocalizedError, Equatable {
        case unreadable(URL, String)
        case notUTF8(URL)
        case empty(URL)

        var errorDescription: String? {
            switch self {
            case let .unreadable(url, reason):
                return "Could not read \(url.lastPathComponent): \(reason)"
            case let .notUTF8(url):
                return "\(url.lastPathComponent) is not encoded as UTF-8."
            case let .empty(url):
                return "\(url.lastPathComponent) is empty."
            }
        }
    }

    init(options: RenderOptions = PreviewRenderDefaults.options) {
        self.options = options
    }

    func loadDocument(from url: URL) throws -> MarkdownDocument {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let byteCount = try fileByteCount(url)

        guard byteCount > 0 else {
            throw LoadError.empty(url)
        }

        if byteCount > options.fastModeByteThreshold {
            let prefixData = try readPrefix(url, byteLimit: options.fastModePreviewByteLimit)
            let source = try decodeUTF8Prefix(prefixData, url: url)
            return MarkdownDocument(source: source, sourceByteCount: byteCount)
        }

        let data = try readFullSmallFile(url)
        let source = try decodeUTF8Full(data, url: url)
        return MarkdownDocument(source: source, sourceByteCount: byteCount)
    }

    private func fileByteCount(_ url: URL) throws -> Int {
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let byteCount = values.fileSize, byteCount >= 0 else {
                throw LoadError.unreadable(url, "File size is unavailable.")
            }
            return byteCount
        } catch let error as LoadError {
            throw error
        } catch {
            throw LoadError.unreadable(url, error.localizedDescription)
        }
    }

    private func readFullSmallFile(_ url: URL) throws -> Data {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            return try handle.readToEnd() ?? Data()
        } catch {
            throw LoadError.unreadable(url, error.localizedDescription)
        }
    }

    private func readPrefix(_ url: URL, byteLimit: Int) throws -> Data {
        guard byteLimit > 0 else {
            return Data()
        }

        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            return try handle.read(upToCount: byteLimit) ?? Data()
        } catch {
            throw LoadError.unreadable(url, error.localizedDescription)
        }
    }

    private func decodeUTF8Full(_ data: Data, url: URL) throws -> String {
        guard let source = String(data: data, encoding: .utf8) else {
            throw LoadError.notUTF8(url)
        }
        return source
    }

    private func decodeUTF8Prefix(_ data: Data, url: URL) throws -> String {
        guard !data.isEmpty else {
            throw LoadError.empty(url)
        }

        if let source = UTF8PrefixDecoder.decode(data) {
            return source
        }

        throw LoadError.notUTF8(url)
    }
}
