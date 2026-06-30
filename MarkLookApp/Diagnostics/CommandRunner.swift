@preconcurrency import Foundation

enum CommandRunner {
    struct CommandResult: Equatable, Sendable {
        var command: DiagnosticsCommand
        var terminationStatus: Int32?
        var standardOutput: String
        var standardError: String
        var didTimeout: Bool
        var launchErrorDescription: String?
        var didTruncateStandardOutput: Bool
        var didTruncateStandardError: Bool

        init(
            command: DiagnosticsCommand,
            terminationStatus: Int32?,
            standardOutput: String,
            standardError: String,
            didTimeout: Bool,
            launchErrorDescription: String?,
            didTruncateStandardOutput: Bool = false,
            didTruncateStandardError: Bool = false,
            outputLimit: Int = 32 * 1024
        ) {
            let cappedOutput = CommandRunner.capped(
                standardOutput,
                limit: outputLimit,
                wasAlreadyTruncated: didTruncateStandardOutput
            )
            let cappedError = CommandRunner.capped(
                standardError,
                limit: outputLimit,
                wasAlreadyTruncated: didTruncateStandardError
            )
            self.command = command
            self.terminationStatus = terminationStatus
            self.standardOutput = cappedOutput.text
            self.standardError = cappedError.text
            self.didTimeout = didTimeout
            self.launchErrorDescription = launchErrorDescription
            self.didTruncateStandardOutput = cappedOutput.didTruncate
            self.didTruncateStandardError = cappedError.didTruncate
        }

        var succeeded: Bool {
            terminationStatus == 0 && !didTimeout && launchErrorDescription == nil
        }

        var summary: String {
            if let launchErrorDescription {
                return "Launch failed: \(launchErrorDescription)"
            }
            if didTimeout {
                return "Timed out"
            }
            if let terminationStatus {
                return "Exit \(terminationStatus)"
            }
            return "Not run"
        }
    }

    static func run(
        _ command: DiagnosticsCommand,
        timeout: TimeInterval = 5,
        outputLimit: Int = 32 * 1024
    ) async -> CommandResult {
        await Task.detached(priority: .utility) {
            runBlocking(command, timeout: timeout, outputLimit: outputLimit)
        }.value
    }

    static func capped(
        _ text: String,
        limit: Int,
        wasAlreadyTruncated: Bool = false
    ) -> (text: String, didTruncate: Bool) {
        guard limit >= 0 else {
            return (text, false)
        }
        if text.count > limit {
            return (String(text.prefix(limit)) + "\n[truncated]", true)
        }
        if wasAlreadyTruncated {
            return (text + "\n[truncated]", true)
        }
        return (text, false)
    }

    private static func runBlocking(
        _ command: DiagnosticsCommand,
        timeout: TimeInterval,
        outputLimit: Int
    ) -> CommandResult {
        let process = Process()
        process.executableURL = command.executableURL
        process.arguments = command.arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        let outputCollector = OutputCollector()
        let errorCollector = OutputCollector()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                outputCollector.append(data, limit: outputLimit)
            }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                errorCollector.append(data, limit: outputLimit)
            }
        }

        do {
            try process.run()
        } catch {
            return CommandResult(
                command: command,
                terminationStatus: nil,
                standardOutput: "",
                standardError: "",
                didTimeout: false,
                launchErrorDescription: error.localizedDescription,
                outputLimit: outputLimit
            )
        }

        let deadline = Date().addingTimeInterval(timeout)
        var didTimeout = false
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }

        if process.isRunning {
            didTimeout = true
            process.terminate()
        }

        process.waitUntilExit()
        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        outputCollector.append(outputPipe.fileHandleForReading.readDataToEndOfFile(), limit: outputLimit)
        errorCollector.append(errorPipe.fileHandleForReading.readDataToEndOfFile(), limit: outputLimit)

        let output = outputCollector.output()
        let error = errorCollector.output()

        return CommandResult(
            command: command,
            terminationStatus: process.terminationStatus,
            standardOutput: output.text,
            standardError: error.text,
            didTimeout: didTimeout,
            launchErrorDescription: nil,
            didTruncateStandardOutput: output.didTruncate,
            didTruncateStandardError: error.didTruncate,
            outputLimit: outputLimit
        )
    }
}

private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    private var didTruncate = false

    func append(_ newData: Data, limit: Int) {
        guard !newData.isEmpty else {
            return
        }
        lock.lock()
        defer { lock.unlock() }

        let remaining = max(0, limit - data.count)
        if remaining > 0 {
            data.append(contentsOf: newData.prefix(remaining))
        }
        if newData.count > remaining {
            didTruncate = true
        }
    }

    func output() -> (text: String, didTruncate: Bool) {
        lock.lock()
        defer { lock.unlock() }

        return (
            String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self),
            didTruncate
        )
    }
}
