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
            contentType: "public.markdown",
            contentTypeTree: ["public.markdown", "public.text"],
            isSupported: true,
            redactedMDLSCommand: "mdls -name kMDItemContentType -name kMDItemContentTypeTree basic.md",
            fullMDLSCommand: "mdls -name kMDItemContentType -name kMDItemContentTypeTree /Users/alice/Secret/basic.md"
        )
        let report = DiagnosticReport(
            generatedAt: Date(timeIntervalSince1970: 1_783_000_000),
            supportedContentTypes: ["public.markdown"],
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

        XCTAssertTrue(text.contains("Version: 0.1.0 (1)"))
        XCTAssertTrue(text.contains("Generated:"))
        XCTAssertTrue(text.contains("Supported content types:"))
        XCTAssertTrue(text.contains("- public.markdown"))
        XCTAssertTrue(text.contains("Supported file extensions:"))
        XCTAssertTrue(text.contains("- md"))
        XCTAssertTrue(text.contains("Preview: registered"))
        XCTAssertTrue(text.contains("Thumbnail: incomplete listing"))
        XCTAssertTrue(text.contains("Selected file: basic.md"))
        XCTAssertTrue(text.contains("kMDItemContentType: public.markdown"))
        XCTAssertTrue(text.contains("Release caveat: Public distribution still requires Developer ID Application signing, notarization, and stapling."))
        XCTAssertFalse(text.contains("/Users/alice/Secret/basic.md"))
    }
}
