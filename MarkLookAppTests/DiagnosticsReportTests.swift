import XCTest

final class DiagnosticsReportTests: XCTestCase {
    func testReportIncludesRequiredFactsAndRedactsFullPathByDefault() {
        let preview = ExtensionRegistrationStatus.parse(
            displayName: "Preview",
            bundleIdentifier: "com.91wan.MarkLook.Preview",
            familyIdentifier: "com.apple.quicklook.preview",
            familyOutput: "com.91wan.MarkLook.Preview",
            familyTerminationStatus: 0,
            exactOutput: "com.91wan.MarkLook.Preview",
            exactTerminationStatus: 0
        )
        let thumbnail = ExtensionRegistrationStatus.parse(
            displayName: "Thumbnail",
            bundleIdentifier: "com.91wan.MarkLook.Thumbnail",
            familyIdentifier: "com.apple.quicklook.thumbnail",
            familyOutput: "",
            familyTerminationStatus: 0,
            exactOutput: "com.91wan.MarkLook.Thumbnail",
            exactTerminationStatus: 0
        )
        let file = FileDiagnostic(
            fileName: "basic.md",
            contentType: "net.daringfireball.markdown",
            contentTypeTree: ["net.daringfireball.markdown", "public.plain-text"],
            hasKnownFileExtension: true,
            quickLookUTIMatch: .matched,
            redactedMDLSCommand: "mdls -name kMDItemContentType -name kMDItemContentTypeTree basic.md",
            fullMDLSCommand: "mdls -name kMDItemContentType -name kMDItemContentTypeTree /tmp/marklook-private/Secret/basic.md"
        )
        let report = DiagnosticReport(
            version: Version(marketingVersion: "9.8.7", buildNumber: "654"),
            generatedAt: Date(timeIntervalSince1970: 1_783_000_000),
            supportedContentTypes: ["net.daringfireball.markdown"],
            supportedFileExtensions: ["md"],
            previewRegistration: preview,
            thumbnailRegistration: thumbnail,
            selectedFile: file,
            resetResults: [
                CommandRunner.CommandResult(
                    command: .quickLookReset,
                    terminationStatus: 0,
                    standardOutput: "",
                    standardError: "",
                    didTimeout: false,
                    launchErrorDescription: nil
                )
            ]
        )

        let text = report.text

        XCTAssertTrue(text.contains("Version: 9.8.7 (654)"))
        XCTAssertTrue(text.contains("Generated:"))
        XCTAssertTrue(text.contains("Supported content types:"))
        XCTAssertTrue(text.contains("- net.daringfireball.markdown"))
        XCTAssertTrue(text.contains("Supported file extensions:"))
        XCTAssertTrue(text.contains("- md"))
        XCTAssertTrue(text.contains("Preview: registered"))
        XCTAssertTrue(text.contains("Thumbnail: incomplete listing"))
        XCTAssertTrue(text.contains("Selected file: basic.md"))
        XCTAssertTrue(text.contains("kMDItemContentType: net.daringfireball.markdown"))
        XCTAssertTrue(text.contains("Known file extension: yes"))
        XCTAssertTrue(text.contains("Quick Look UTI match: yes"))
        XCTAssertTrue(text.contains("Release caveat: Public distribution still requires Developer ID Application signing, notarization, and stapling."))
        XCTAssertFalse(text.contains("/tmp/marklook-private/Secret/basic.md"))
    }

    func testReportDistinguishesUnavailableQuickLookMatch() {
        let file = FileDiagnostic(
            fileName: "notes.md",
            contentType: "unavailable",
            contentTypeTree: [],
            hasKnownFileExtension: true,
            quickLookUTIMatch: .unavailable,
            redactedMDLSCommand: "mdls notes.md",
            fullMDLSCommand: "mdls /tmp/marklook-private/Secret/notes.md"
        )

        let report = DiagnosticReport(selectedFile: file)

        XCTAssertTrue(report.text.contains("Quick Look UTI match: unavailable"))
        XCTAssertFalse(report.text.contains("Quick Look UTI match: no"))
    }

    func testVersionReadsBundleMetadata() throws {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("VersionFixture.bundle", isDirectory: true)
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(
            at: contentsURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent())
        }

        let info: [String: Any] = [
            "CFBundleIdentifier": "com.91wan.MarkLook.VersionFixture",
            "CFBundlePackageType": "BNDL",
            "CFBundleShortVersionString": "9.8.7",
            "CFBundleVersion": "654"
        ]
        let plist = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try plist.write(to: contentsURL.appendingPathComponent("Info.plist"))

        let bundle = try XCTUnwrap(Bundle(url: bundleURL))

        XCTAssertEqual(
            Version(bundle: bundle),
            Version(marketingVersion: "9.8.7", buildNumber: "654")
        )
    }
}
