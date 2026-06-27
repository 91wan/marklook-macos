import SwiftUI

struct ContentView: View {
    private let resetCommands = [
        "qlmanage -r",
        "qlmanage -r cache",
        "killall Finder || true"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                statusSection
                DiagnosticsView(resetCommands: resetCommands)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(28)
        }
        .frame(minWidth: 680, minHeight: 560)
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MarkLook")
                .font(.largeTitle.weight(.semibold))
            Text("Fast local Markdown Quick Look for AI/developer docs.")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("MarkLook is a Quick Look Markdown preview app. It is not a Markdown editor.")
                .foregroundStyle(.secondary)
        }
    }

    private var statusSection: some View {
        GroupBox("Status") {
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(text: "App shell installed.")
                StatusRow(text: "Preview extension shell builds and is embedded.")
                StatusRow(text: "Thumbnail extension shell builds and is embedded.")
                StatusRow(text: "Preview rendering lands in Issue #4.")
                StatusRow(text: "Thumbnail rendering lands in Issue #5.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatusRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.green)
                .imageScale(.small)
            Text(text)
        }
    }
}
