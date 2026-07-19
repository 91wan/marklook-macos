import Foundation

struct DiagnosticReport: Sendable {
    var version: Version
    var generatedAt: Date
    var supportedContentTypes: [String]
    var supportedFileExtensions: [String]
    var previewRegistration: ExtensionRegistrationStatus
    var thumbnailRegistration: ExtensionRegistrationStatus
    var selectedFile: FileDiagnostic?
    var resetResults: [CommandRunner.CommandResult]

    init(
        version: Version = .current,
        generatedAt: Date = Date(),
        supportedContentTypes: [String] = SupportedTypes.contentTypes,
        supportedFileExtensions: [String] = SupportedTypes.fileExtensions,
        previewRegistration: ExtensionRegistrationStatus = .previewUnchecked,
        thumbnailRegistration: ExtensionRegistrationStatus = .thumbnailUnchecked,
        selectedFile: FileDiagnostic? = nil,
        resetResults: [CommandRunner.CommandResult] = []
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.supportedContentTypes = supportedContentTypes
        self.supportedFileExtensions = supportedFileExtensions
        self.previewRegistration = previewRegistration
        self.thumbnailRegistration = thumbnailRegistration
        self.selectedFile = selectedFile
        self.resetResults = resetResults
    }

    var text: String {
        var lines = [
            "MarkLook diagnostics report",
            "Version: \(version.marketingVersion) (\(version.buildNumber))",
            "Generated: \(generatedAt.ISO8601Format())",
            "Release caveat: Public distribution still requires Developer ID Application signing, notarization, and stapling.",
            "",
            "Supported content types:"
        ]
        lines.append(contentsOf: supportedContentTypes.map { "- \($0)" })
        lines.append("")
        lines.append("Supported file extensions:")
        lines.append(contentsOf: supportedFileExtensions.map { "- \($0)" })
        lines.append("")
        lines.append("Quick Look extensions:")
        lines.append(registrationLine(previewRegistration))
        lines.append(registrationLine(thumbnailRegistration))
        lines.append("")
        lines.append("Selected file:")
        if let selectedFile {
            lines.append("- Selected file: \(selectedFile.fileName)")
            lines.append("- kMDItemContentType: \(selectedFile.contentType)")
            lines.append("- Content type tree: \(selectedFile.contentTypeTree.joined(separator: ", "))")
            lines.append("- Known file extension: \(selectedFile.hasKnownFileExtension ? "yes" : "no")")
            lines.append("- Quick Look UTI match: \(selectedFile.quickLookUTIMatch.label)")
            lines.append("- mdls command: \(selectedFile.redactedMDLSCommand)")
        } else {
            lines.append("- none")
        }
        lines.append("")
        lines.append("Reset Quick Look results:")
        if resetResults.isEmpty {
            lines.append(contentsOf: DiagnosticsCommand.resetQuickLookCommands.map {
                "- \($0.displayString(redactFilePaths: true)): not run"
            })
        } else {
            lines.append(contentsOf: resetResults.map {
                "- \($0.command.displayString(redactFilePaths: true)): \($0.summary)"
            })
        }
        lines.append("")
        lines.append("Manual enable instructions:")
        lines.append("- System Settings -> General -> Login Items & Extensions -> Quick Look")
        return lines.joined(separator: "\n")
    }

    private func registrationLine(_ status: ExtensionRegistrationStatus) -> String {
        "- \(status.displayName): \(status.effectiveStatus.label) (family: \(status.familyQueryState.label), exact bundle id: \(status.exactQueryState.label))"
    }
}
