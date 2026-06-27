import Foundation
import MarkdownCore

struct MarkdownPreviewLoader {
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

    func loadDocument(from url: URL) throws -> MarkdownDocument {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw LoadError.unreadable(url, error.localizedDescription)
        }

        guard !data.isEmpty else {
            throw LoadError.empty(url)
        }

        guard let source = String(data: data, encoding: .utf8) else {
            throw LoadError.notUTF8(url)
        }

        return MarkdownDocument(source: source)
    }
}
