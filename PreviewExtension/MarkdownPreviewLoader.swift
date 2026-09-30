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

        let readBudget = try boundedReadBudget(url)
        let advisoryByteCount = try fileByteCount(url)
        let data = try readBoundedFile(url, byteLimit: readBudget)

        guard !data.isEmpty else {
            throw LoadError.empty(url)
        }

        if data.count > options.fastModeByteThreshold {
            let prefixData = Data(data.prefix(options.fastModePreviewByteLimit))
            let source = try decodeUTF8Prefix(prefixData, url: url)
            return MarkdownDocument(source: source, sourceByteCount: max(advisoryByteCount, data.count))
        }

        let source = try decodeUTF8Full(data, url: url)
        return MarkdownDocument(source: source, sourceByteCount: data.count)
    }

    private func boundedReadBudget(_ url: URL) throws -> Int {
        let threshold = options.fastModeByteThreshold
        let prefixLimit = options.fastModePreviewByteLimit
        let (classificationLimit, overflow) = threshold.addingReportingOverflow(1)
        guard threshold >= 0, prefixLimit >= 0, !overflow else {
            throw LoadError.unreadable(url, "Preview byte limits are invalid.")
        }
        return max(classificationLimit, prefixLimit)
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

    private func readBoundedFile(_ url: URL, byteLimit: Int) throws -> Data {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var data = Data()
            while data.count < byteLimit {
                let chunkLimit = min(65_536, byteLimit - data.count)
                guard let chunk = try handle.read(upToCount: chunkLimit), !chunk.isEmpty else {
                    break
                }
                data.append(chunk)
            }
            return data
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
