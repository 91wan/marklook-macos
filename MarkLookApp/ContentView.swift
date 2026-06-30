import SwiftUI

struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                DiagnosticsView()
            }
            .frame(maxWidth: 880, alignment: .leading)
            .padding(28)
        }
        .frame(minWidth: 760, minHeight: 680)
        .background(.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MarkLook")
                .font(.largeTitle.weight(.semibold))
            Text("Quick Look Markdown diagnostics")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("MarkLook is a Quick Look Markdown preview app. It is not a Markdown editor.")
                .foregroundStyle(.secondary)
        }
    }
}
