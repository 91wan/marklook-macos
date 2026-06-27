import Foundation

struct DiagnosticReport: Sendable {
    var generatedAt: Date
    var supportedContentTypes: [String]
    var resetCommands: [String]

    init(
        generatedAt: Date = Date(),
        supportedContentTypes: [String] = SupportedTypes.contentTypes,
        resetCommands: [String] = ["qlmanage -r", "qlmanage -r cache", "killall Finder || true"]
    ) {
        self.generatedAt = generatedAt
        self.supportedContentTypes = supportedContentTypes
        self.resetCommands = resetCommands
    }

    var text: String {
        var lines = [
            "MarkLook diagnostics",
            "Generated: \(generatedAt.ISO8601Format())",
            "",
            "Supported content types:"
        ]
        lines.append(contentsOf: supportedContentTypes.map { "- \($0)" })
        lines.append("")
        lines.append("Reset commands:")
        lines.append(contentsOf: resetCommands.map { "- \($0)" })
        return lines.joined(separator: "\n")
    }
}
