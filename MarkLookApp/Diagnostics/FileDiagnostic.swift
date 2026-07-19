import Foundation

enum QuickLookUTIMatchStatus: Equatable, Sendable {
    case matched
    case notMatched
    case unavailable

    var label: String {
        switch self {
        case .matched:
            "yes"
        case .notMatched:
            "no"
        case .unavailable:
            "unavailable"
        }
    }
}

struct FileDiagnostic: Equatable, Sendable {
    var fileName: String
    var contentType: String
    var contentTypeTree: [String]
    var hasKnownFileExtension: Bool
    var quickLookUTIMatch: QuickLookUTIMatchStatus
    var redactedMDLSCommand: String
    var fullMDLSCommand: String

    static func parse(
        mdlsOutput: String,
        fileURL: URL,
        mdlsSucceeded: Bool
    ) -> FileDiagnostic {
        let command = DiagnosticsCommand.mdls(fileURL: fileURL)
        let parsedContentType = parseScalarValue(named: "kMDItemContentType", in: mdlsOutput)
        let contentType = parsedContentType ?? "unavailable"
        let contentTypeTree = parseArrayValue(named: "kMDItemContentTypeTree", in: mdlsOutput)
        let pathExtension = fileURL.pathExtension.lowercased()
        let supportedTypes = Set(SupportedTypes.contentTypes)
        let supportedExtensions = Set(SupportedTypes.fileExtensions)
        let quickLookUTIMatch: QuickLookUTIMatchStatus
        if !mdlsSucceeded || parsedContentType == nil {
            quickLookUTIMatch = .unavailable
        } else if supportedTypes.contains(contentType) {
            quickLookUTIMatch = .matched
        } else {
            quickLookUTIMatch = .notMatched
        }

        return FileDiagnostic(
            fileName: fileURL.lastPathComponent,
            contentType: contentType,
            contentTypeTree: contentTypeTree,
            hasKnownFileExtension: supportedExtensions.contains(pathExtension),
            quickLookUTIMatch: quickLookUTIMatch,
            redactedMDLSCommand: command.displayString(redactFilePaths: true),
            fullMDLSCommand: command.displayString(redactFilePaths: false)
        )
    }

    private static func parseScalarValue(named key: String, in output: String) -> String? {
        output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                let text = line.trimmingCharacters(in: .whitespaces)
                guard text.hasPrefix(key), text.contains("=") else {
                    return nil
                }
                return quotedValues(in: text).first
            }
            .first
    }

    private static func parseArrayValue(named key: String, in output: String) -> [String] {
        var values: [String] = []
        var isReadingArray = false

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line).trimmingCharacters(in: .whitespaces)
            if text.hasPrefix(key), text.contains("="), text.contains("(") {
                isReadingArray = true
                values.append(contentsOf: quotedValues(in: text))
                if text.contains(")") {
                    break
                }
                continue
            }

            guard isReadingArray else {
                continue
            }

            if text.contains(")") {
                values.append(contentsOf: quotedValues(in: text))
                break
            }

            values.append(contentsOf: quotedValues(in: text))
        }

        return values
    }

    private static func quotedValues(in text: String) -> [String] {
        var values: [String] = []
        var remainder = text[...]

        while let start = remainder.firstIndex(of: "\"") {
            let afterStart = remainder.index(after: start)
            guard let end = remainder[afterStart...].firstIndex(of: "\"") else {
                break
            }
            values.append(String(remainder[afterStart..<end]))
            remainder = remainder[remainder.index(after: end)...]
        }

        return values
    }
}
