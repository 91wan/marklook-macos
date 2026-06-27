import Foundation

enum CommandRunner {
    struct CommandResult: Sendable {
        let terminationStatus: Int32
        let standardOutput: String
        let standardError: String
    }

    static func run(_ executableURL: URL, arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return CommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: output,
            standardError: error
        )
    }
}
