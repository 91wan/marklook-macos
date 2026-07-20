import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class DiagnosticsViewModel: ObservableObject {
    typealias CommandExecutor = @Sendable (DiagnosticsCommand) async -> CommandRunner.CommandResult

    static let manualEnableInstructions = "System Settings -> General -> Login Items & Extensions -> Quick Look"

    @Published var previewRegistration: ExtensionRegistrationStatus = .previewUnchecked
    @Published var thumbnailRegistration: ExtensionRegistrationStatus = .thumbnailUnchecked
    @Published var registrationCommandResults: [CommandRunner.CommandResult] = []
    @Published var selectedFile: FileDiagnostic?
    @Published var selectedFileCommandResult: CommandRunner.CommandResult?
    @Published var resetResults: [CommandRunner.CommandResult] = []
    @Published var isRefreshingRegistration = false
    @Published var isDiagnosingFile = false
    @Published var isResettingQuickLook = false
    @Published var copyStatus: String?

    private let commandExecutor: CommandExecutor

    init(commandExecutor: @escaping CommandExecutor = { command in
        await CommandRunner.run(command)
    }) {
        self.commandExecutor = commandExecutor
    }

    var reportText: String {
        DiagnosticReport(
            previewRegistration: previewRegistration,
            thumbnailRegistration: thumbnailRegistration,
            selectedFile: selectedFile,
            resetResults: resetResults
        ).text
    }

    func refreshRegistration() async {
        isRefreshingRegistration = true
        defer { isRefreshingRegistration = false }

        let previewFamilyCommand = DiagnosticsCommand.plugInKitFamily("com.apple.quicklook.preview")
        let previewExactCommand = DiagnosticsCommand.plugInKitExact("com.91wan.MarkLook.Preview")
        let thumbnailFamilyCommand = DiagnosticsCommand.plugInKitFamily("com.apple.quicklook.thumbnail")
        let thumbnailExactCommand = DiagnosticsCommand.plugInKitExact("com.91wan.MarkLook.Thumbnail")

        async let previewFamily = commandExecutor(previewFamilyCommand)
        async let previewExact = commandExecutor(previewExactCommand)
        async let thumbnailFamily = commandExecutor(thumbnailFamilyCommand)
        async let thumbnailExact = commandExecutor(thumbnailExactCommand)

        let previewFamilyResult = await previewFamily
        let previewExactResult = await previewExact
        let thumbnailFamilyResult = await thumbnailFamily
        let thumbnailExactResult = await thumbnailExact
        registrationCommandResults = [
            previewFamilyResult,
            previewExactResult,
            thumbnailFamilyResult,
            thumbnailExactResult
        ]

        previewRegistration = ExtensionRegistrationStatus.parse(
            displayName: "Preview",
            bundleIdentifier: "com.91wan.MarkLook.Preview",
            familyIdentifier: "com.apple.quicklook.preview",
            familyOutput: previewFamilyResult.standardOutput + previewFamilyResult.standardError,
            familyTerminationStatus: previewFamilyResult.terminationStatus,
            exactOutput: previewExactResult.standardOutput + previewExactResult.standardError,
            exactTerminationStatus: previewExactResult.terminationStatus
        )
        thumbnailRegistration = ExtensionRegistrationStatus.parse(
            displayName: "Thumbnail",
            bundleIdentifier: "com.91wan.MarkLook.Thumbnail",
            familyIdentifier: "com.apple.quicklook.thumbnail",
            familyOutput: thumbnailFamilyResult.standardOutput + thumbnailFamilyResult.standardError,
            familyTerminationStatus: thumbnailFamilyResult.terminationStatus,
            exactOutput: thumbnailExactResult.standardOutput + thumbnailExactResult.standardError,
            exactTerminationStatus: thumbnailExactResult.terminationStatus
        )
    }

    func selectFile() async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = markdownContentTypes()
        panel.prompt = "Diagnose"
        panel.message = "Choose a Markdown file to inspect its Launch Services content type."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        await diagnose(fileURL: url)
    }

    func diagnose(fileURL: URL) async {
        isDiagnosingFile = true
        defer { isDiagnosingFile = false }

        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let command = DiagnosticsCommand.mdls(fileURL: fileURL)
        let result = await commandExecutor(command)
        selectedFileCommandResult = result
        selectedFile = FileDiagnostic.parse(
            mdlsOutput: result.standardOutput,
            fileURL: fileURL,
            mdlsSucceeded: result.succeeded
        )
    }

    func resetQuickLookCache() async {
        isResettingQuickLook = true
        defer { isResettingQuickLook = false }

        var results: [CommandRunner.CommandResult] = []
        for command in DiagnosticsCommand.resetQuickLookCommands {
            results.append(await commandExecutor(command))
        }
        resetResults = results
    }

    func copyReport() {
        copy(reportText)
        copyStatus = "Report copied"
    }

    func copyManualEnableInstructions() {
        copy(Self.manualEnableInstructions)
        copyStatus = "Manual enable instructions copied"
    }

    func copyResetCommands() {
        let text = DiagnosticsCommand.resetQuickLookCommands
            .map { $0.displayString(redactFilePaths: true) }
            .joined(separator: "\n")
        copy(text)
        copyStatus = "Reset commands copied"
    }

    func copyRegistrationCommands() {
        let text = DiagnosticsCommand.registrationCommands
            .map { $0.displayString(redactFilePaths: true) }
            .joined(separator: "\n")
        copy(text)
        copyStatus = "Registration commands copied"
    }

    func copyRedactedMDLSCommand() {
        guard let selectedFile else {
            return
        }
        copy(selectedFile.redactedMDLSCommand)
        copyStatus = "Redacted mdls command copied"
    }

    func copyFullMDLSCommand() {
        guard let selectedFile else {
            return
        }
        copy(selectedFile.fullMDLSCommand)
        copyStatus = "Full-path mdls command copied"
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func markdownContentTypes() -> [UTType] {
        var types: [UTType] = SupportedTypes.contentTypes.map { UTType(importedAs: $0) }
        types.append(contentsOf: SupportedTypes.fileExtensions.compactMap { UTType(filenameExtension: $0) })
        return types
    }
}
