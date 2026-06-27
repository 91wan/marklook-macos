import SwiftUI

struct DiagnosticsView: View {
    let resetCommands: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            enableSection
            supportedTypesSection
            commandsSection
        }
    }

    private var enableSection: some View {
        GroupBox("Enable") {
            Text("System Settings -> General -> Login Items & Extensions -> Quick Look")
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var supportedTypesSection: some View {
        GroupBox("Supported Content Types") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(SupportedTypes.contentTypes, id: \.self) { type in
                    Text(type)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var commandsSection: some View {
        GroupBox("Reset Quick Look Cache") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(resetCommands, id: \.self) { command in
                    Text(command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
