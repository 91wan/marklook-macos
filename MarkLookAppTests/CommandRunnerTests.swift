import XCTest

final class CommandRunnerTests: XCTestCase {
    func testFormatsRedactedCommandDescription() {
        let command = DiagnosticsCommand.mdls(
            fileURL: URL(fileURLWithPath: "/tmp/marklook-private/Documents/Secret/basic.md")
        )

        XCTAssertEqual(
            command.displayString(redactFilePaths: true),
            "mdls -name kMDItemContentType -name kMDItemContentTypeTree basic.md"
        )
        XCTAssertTrue(
            command.displayString(redactFilePaths: false)
                .contains("/tmp/marklook-private/Documents/Secret/basic.md")
        )
    }

    func testCommandResultTruncatesLongOutputStreams() {
        let result = CommandRunner.CommandResult(
            command: .quickLookReset,
            terminationStatus: 0,
            standardOutput: String(repeating: "o", count: 80),
            standardError: String(repeating: "e", count: 80),
            didTimeout: false,
            launchErrorDescription: nil,
            outputLimit: 24
        )

        XCTAssertTrue(result.didTruncateStandardOutput)
        XCTAssertTrue(result.didTruncateStandardError)
        XCTAssertTrue(result.standardOutput.contains("[truncated]"))
        XCTAssertTrue(result.standardError.contains("[truncated]"))
    }

    func testLaunchFailureReturnsStructuredResult() async {
        let command = DiagnosticsCommand(
            executablePath: "/does/not/exist/marklook-missing-command",
            arguments: [],
            redactedArguments: [],
            displayName: "missing-command"
        )

        let result = await CommandRunner.run(command, timeout: 1)

        XCTAssertNil(result.terminationStatus)
        XCTAssertNotNil(result.launchErrorDescription)
        XCTAssertFalse(result.succeeded)
        XCTAssertTrue(result.summary.contains("Launch failed"))
    }

    func testTimeoutForceKillsProcessThatIgnoresTermination() async {
        let command = DiagnosticsCommand(
            executablePath: "/usr/bin/python3",
            arguments: [
                "-c",
                "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(5)",
            ],
            redactedArguments: ["-c", "<timeout fixture>"],
            displayName: "timeout-fixture"
        )
        let start = Date()

        let result = await CommandRunner.run(
            command,
            timeout: 0.5,
            terminationGracePeriod: 0.1
        )

        XCTAssertTrue(result.didTimeout)
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.terminationStatus, SIGKILL)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
    }
}
