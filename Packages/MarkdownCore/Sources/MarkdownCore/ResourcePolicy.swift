import Foundation

public struct RenderDiagnostic: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case fastMode
        case blockedRemoteResource
        case unsafeLink
        case rawHTMLBlocked
    }

    public let kind: Kind
    public let message: String

    public init(kind: Kind, message: String) {
        self.kind = kind
        self.message = message
    }
}

struct ResourcePolicy {
    let options: RenderOptions

    func sanitizeText(_ text: String, diagnostics: inout [RenderDiagnostic]) -> String {
        if options.allowRawHTML {
            return text
        }

        let escaped = Self.escapeHTML(text)
        guard Self.containsRawHTML(text) else {
            return escaped
        }

        diagnostics.append(RenderDiagnostic(kind: .rawHTMLBlocked, message: "Raw HTML was escaped."))
        return Self.neutralizeDangerousText(escaped)
    }

    func renderImage(alt: String, url: String, diagnostics: inout [RenderDiagnostic]) -> String {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerURL = trimmedURL.lowercased()
        let escapedAlt = Self.escapeAttribute(alt)

        if lowerURL.hasPrefix("data:image/"), options.allowRemoteResources {
            return "<img alt=\"\(escapedAlt)\" src=\"\(Self.escapeAttribute(trimmedURL))\">"
        }

        diagnostics.append(RenderDiagnostic(kind: .blockedRemoteResource, message: "Image resource was blocked."))
        let label = alt.isEmpty ? "image" : Self.escapeHTML(alt)
        return "<span class=\"blocked-resource\">Remote image blocked: \(label)</span>"
    }

    func renderLink(labelHTML: String, url: String, diagnostics: inout [RenderDiagnostic]) -> String {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isUnsafeLink(trimmedURL) {
            diagnostics.append(RenderDiagnostic(kind: .unsafeLink, message: "Unsafe link target was replaced."))
            return "<a href=\"#\">\(labelHTML)</a>"
        }

        return "<a href=\"\(Self.escapeAttribute(trimmedURL))\">\(labelHTML)</a>"
    }

    static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func escapeAttribute(_ text: String) -> String {
        escapeHTML(text)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    static func containsRawHTML(_ text: String) -> Bool {
        text.range(of: #"<\s*/?\s*[a-zA-Z][^>]*>"#, options: .regularExpression) != nil
    }

    static func isUnsafeLink(_ url: String) -> Bool {
        let lowerURL = url.lowercased()
        return lowerURL.hasPrefix("javascript:")
            || lowerURL.hasPrefix("vbscript:")
            || lowerURL.hasPrefix("data:text/html")
    }

    private static func neutralizeDangerousText(_ escaped: String) -> String {
        var sanitized = escaped
        sanitized = sanitized.replacingOccurrences(
            of: #"(?i)\bonerror="#,
            with: "onerror&#61;",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"(?i)\bonclick="#,
            with: "onclick&#61;",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"(?i)\bonload="#,
            with: "onload&#61;",
            options: .regularExpression
        )
        sanitized = sanitized.replacingOccurrences(
            of: #"(?i)javascript:"#,
            with: "javascript&#58;",
            options: .regularExpression
        )
        return sanitized
    }
}
