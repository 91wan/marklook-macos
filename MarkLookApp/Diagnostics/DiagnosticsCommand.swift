import Foundation

struct DiagnosticsCommand: Equatable, Sendable {
    var executablePath: String
    var arguments: [String]
    var redactedArguments: [String]
    var displayName: String
    var displayOverride: String?

    init(
        executablePath: String,
        arguments: [String],
        redactedArguments: [String]? = nil,
        displayName: String? = nil,
        displayOverride: String? = nil
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.redactedArguments = redactedArguments ?? arguments
        self.displayName = displayName ?? URL(fileURLWithPath: executablePath).lastPathComponent
        self.displayOverride = displayOverride
    }

    var executableURL: URL {
        URL(fileURLWithPath: executablePath)
    }

    func displayString(redactFilePaths: Bool) -> String {
        if let displayOverride {
            return displayOverride
        }

        let displayArguments = redactFilePaths ? redactedArguments : arguments
        return ([displayName] + displayArguments)
            .map(Self.shellEscaped)
            .joined(separator: " ")
    }

    static func mdls(fileURL: URL) -> DiagnosticsCommand {
        let arguments = [
            "-name", "kMDItemContentType",
            "-name", "kMDItemContentTypeTree",
            fileURL.path
        ]
        let redactedArguments = [
            "-name", "kMDItemContentType",
            "-name", "kMDItemContentTypeTree",
            fileURL.lastPathComponent
        ]
        return DiagnosticsCommand(
            executablePath: "/usr/bin/mdls",
            arguments: arguments,
            redactedArguments: redactedArguments,
            displayName: "mdls"
        )
    }

    static func plugInKitFamily(_ familyIdentifier: String) -> DiagnosticsCommand {
        DiagnosticsCommand(
            executablePath: "/usr/bin/pluginkit",
            arguments: ["-mAv", "-p", familyIdentifier],
            displayName: "pluginkit"
        )
    }

    static func plugInKitExact(_ bundleIdentifier: String) -> DiagnosticsCommand {
        DiagnosticsCommand(
            executablePath: "/usr/bin/pluginkit",
            arguments: ["-mAv", "-i", bundleIdentifier],
            displayName: "pluginkit"
        )
    }

    static let quickLookReset = DiagnosticsCommand(
        executablePath: "/usr/bin/qlmanage",
        arguments: ["-r"],
        displayName: "qlmanage"
    )

    static let quickLookCacheReset = DiagnosticsCommand(
        executablePath: "/usr/bin/qlmanage",
        arguments: ["-r", "cache"],
        displayName: "qlmanage"
    )

    static let restartFinder = DiagnosticsCommand(
        executablePath: "/usr/bin/killall",
        arguments: ["Finder"],
        displayName: "killall",
        displayOverride: "killall Finder || true"
    )

    static let resetQuickLookCommands = [
        quickLookReset,
        quickLookCacheReset,
        restartFinder
    ]

    static let registrationCommands = [
        plugInKitFamily("com.apple.quicklook.preview"),
        plugInKitExact("com.91wan.MarkLook.Preview"),
        plugInKitFamily("com.apple.quicklook.thumbnail"),
        plugInKitExact("com.91wan.MarkLook.Thumbnail")
    ]

    private static func shellEscaped(_ value: String) -> String {
        guard !value.isEmpty else {
            return "''"
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./:-")
        if value.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
