import SwiftUI

@MainActor
struct DiagnosticsView: View {
    @StateObject private var viewModel: DiagnosticsViewModel

    init(viewModel: DiagnosticsViewModel = DiagnosticsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            statusSection
            registrationSection
            supportedTypesSection
            diagnoseSection
            resetSection
            reportSection
            manualEnableSection
        }
        .task {
            await viewModel.refreshRegistration()
        }
    }

    private var statusSection: some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: 8) {
                StatusLine(text: "Preview: data-based HTML Quick Look preview validated locally.", symbol: "checkmark.circle")
                StatusLine(text: "Thumbnail: bounded Markdown thumbnail renderer validated locally.", symbol: "checkmark.circle")
                StatusLine(text: "Local validation: Apple Development signing validated on maintainer Mac.", symbol: "checkmark.circle")
                StatusLine(text: "Public release: Developer ID, notarization, and stapling are still future work.", symbol: "exclamationmark.triangle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var registrationSection: some View {
        GroupBox("Quick Look Extensions") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Registration status")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await viewModel.refreshRegistration() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isRefreshingRegistration)
                }

                RegistrationStatusView(status: viewModel.previewRegistration)
                Divider()
                RegistrationStatusView(status: viewModel.thumbnailRegistration)
                if viewModel.registrationCommandResults.contains(where: { !$0.succeeded }) {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Registration commands failed inside the app sandbox. Copy these commands and run them in Terminal for manual verification.")
                            .foregroundStyle(.secondary)
                        Button {
                            viewModel.copyRegistrationCommands()
                        } label: {
                            Label("Copy Registration Commands", systemImage: "terminal")
                        }
                        ForEach(Array(viewModel.registrationCommandResults.enumerated()), id: \.offset) { _, result in
                            if !result.succeeded {
                                CommandResultView(result: result)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var supportedTypesSection: some View {
        GroupBox("Supported Markdown Types") {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Content types")
                        .font(.headline)
                    ForEach(SupportedTypes.contentTypes, id: \.self) { type in
                        MonospacedLine(type)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("File extensions")
                        .font(.headline)
                    ForEach(SupportedTypes.fileExtensions, id: \.self) { fileExtension in
                        MonospacedLine(".\(fileExtension)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var diagnoseSection: some View {
        GroupBox("Diagnose a Markdown File") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        Task { await viewModel.selectFile() }
                    } label: {
                        Label("Select File", systemImage: "doc.badge.magnifyingglass")
                    }
                    .disabled(viewModel.isDiagnosingFile)

                    if viewModel.isDiagnosingFile {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let selectedFile = viewModel.selectedFile {
                    InfoRow(label: "File", value: selectedFile.fileName)
                    InfoRow(label: "kMDItemContentType", value: selectedFile.contentType)
                    InfoRow(label: "Known file extension", value: selectedFile.hasKnownFileExtension ? "yes" : "no")
                    InfoRow(label: "Quick Look UTI match", value: selectedFile.quickLookUTIMatch.label)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Content type tree")
                            .font(.headline)
                        if selectedFile.contentTypeTree.isEmpty {
                            Text("No content type tree returned by mdls.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(selectedFile.contentTypeTree, id: \.self) { type in
                                MonospacedLine(type)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("mdls command")
                            .font(.headline)
                        MonospacedLine(selectedFile.redactedMDLSCommand)
                        HStack {
                            Button {
                                viewModel.copyRedactedMDLSCommand()
                            } label: {
                                Label("Copy Redacted Command", systemImage: "doc.on.doc")
                            }
                            Button {
                                viewModel.copyFullMDLSCommand()
                            } label: {
                                Label("Copy Command With Full Path", systemImage: "lock.open")
                            }
                        }
                    }
                    if let result = viewModel.selectedFileCommandResult {
                        CommandResultView(result: result)
                    }
                } else {
                    Text("No file selected.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var resetSection: some View {
        GroupBox("Reset Quick Look Cache") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        Task { await viewModel.resetQuickLookCache() }
                    } label: {
                        Label("Reset Quick Look Cache", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(viewModel.isResettingQuickLook)

                    Button {
                        viewModel.copyResetCommands()
                    } label: {
                        Label("Copy Manual Commands", systemImage: "terminal")
                    }

                    if viewModel.isResettingQuickLook {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if viewModel.resetResults.isEmpty {
                    ForEach(Array(DiagnosticsCommand.resetQuickLookCommands.enumerated()), id: \.offset) { _, command in
                        MonospacedLine(command.displayString(redactFilePaths: true))
                    }
                } else {
                    ForEach(Array(viewModel.resetResults.enumerated()), id: \.offset) { _, result in
                        CommandResultView(result: result)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reportSection: some View {
        GroupBox("Copy Diagnostics Report") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        viewModel.copyReport()
                    } label: {
                        Label("Copy Report", systemImage: "doc.on.clipboard")
                    }
                    if let copyStatus = viewModel.copyStatus {
                        Text(copyStatus)
                            .foregroundStyle(.secondary)
                    }
                }
                ScrollView {
                    Text(viewModel.reportText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 140, maxHeight: 220)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var manualEnableSection: some View {
        GroupBox("Manual Enable Instructions") {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                MonospacedLine(DiagnosticsViewModel.manualEnableInstructions)
                Spacer()
                Button {
                    viewModel.copyManualEnableInstructions()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RegistrationStatusView: View {
    let status: ExtensionRegistrationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(status.displayName, systemImage: symbolName)
                    .font(.headline)
                Text(status.effectiveStatus.label)
                    .foregroundStyle(statusColor)
            }
            InfoRow(label: "Bundle ID", value: status.bundleIdentifier)
            InfoRow(label: "Family query", value: "\(status.familyIdentifier): \(status.familyQueryState.label)")
            InfoRow(label: "Exact bundle query", value: status.exactQueryState.label)
        }
    }

    private var symbolName: String {
        switch status.effectiveStatus {
        case .registered:
            return "checkmark.circle"
        case .incompleteListing:
            return "exclamationmark.triangle"
        case .missing, .error:
            return "xmark.circle"
        case .notChecked:
            return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch status.effectiveStatus {
        case .registered:
            return .green
        case .incompleteListing:
            return .orange
        case .missing, .error:
            return .red
        case .notChecked:
            return .secondary
        }
    }
}

private struct CommandResultView: View {
    let result: CommandRunner.CommandResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            InfoRow(label: "Command", value: result.command.displayString(redactFilePaths: true))
            InfoRow(label: "Result", value: result.summary)
            if !result.standardOutput.isEmpty {
                OutputBlock(title: "stdout", text: result.standardOutput)
            }
            if !result.standardError.isEmpty {
                OutputBlock(title: "stderr", text: result.standardError)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct OutputBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

private struct MonospacedLine: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
    }
}

private struct StatusLine: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(symbol == "checkmark.circle" ? .green : .orange)
                .imageScale(.small)
            Text(text)
        }
    }
}
