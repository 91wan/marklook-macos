import XCTest

final class DiagnosticsParsingTests: XCTestCase {
    func testParsesMdlsContentTypeAndTree() {
        let output = """
        kMDItemContentType     = "net.daringfireball.markdown"
        kMDItemContentTypeTree = (
            "net.daringfireball.markdown",
            "public.text",
            "public.data",
            "public.item",
            "public.content"
        )
        """

        let diagnostic = FileDiagnostic.parse(
            mdlsOutput: output,
            fileURL: URL(fileURLWithPath: "/Users/alice/Documents/basic.md")
        )

        XCTAssertEqual(diagnostic.fileName, "basic.md")
        XCTAssertEqual(diagnostic.contentType, "net.daringfireball.markdown")
        XCTAssertEqual(diagnostic.contentTypeTree, [
            "net.daringfireball.markdown",
            "public.text",
            "public.data",
            "public.item",
            "public.content"
        ])
        XCTAssertTrue(diagnostic.isSupported)
    }

    func testSupportedMarkdownTypeFromTree() {
        let output = """
        kMDItemContentType = "dyn.ah62d4rv4ge81g5p"
        kMDItemContentTypeTree = (
            "dyn.ah62d4rv4ge81g5p",
            "public.markdown",
            "public.text"
        )
        """

        let diagnostic = FileDiagnostic.parse(
            mdlsOutput: output,
            fileURL: URL(fileURLWithPath: "/Users/alice/Documents/notes.md")
        )

        XCTAssertEqual(diagnostic.contentType, "dyn.ah62d4rv4ge81g5p")
        XCTAssertTrue(diagnostic.isSupported)
    }

    func testUnknownContentTypeIsUnsupported() {
        let output = """
        kMDItemContentType = "com.example.binary"
        kMDItemContentTypeTree = (
            "com.example.binary",
            "public.data"
        )
        """

        let diagnostic = FileDiagnostic.parse(
            mdlsOutput: output,
            fileURL: URL(fileURLWithPath: "/Users/alice/Documents/blob.bin")
        )

        XCTAssertFalse(diagnostic.isSupported)
    }

    func testPreviewFamilyAndExactRegistrationPresent() {
        let status = ExtensionRegistrationStatus.parse(
            displayName: "Preview",
            bundleIdentifier: "com.91wan.MarkLook.Preview",
            familyIdentifier: "com.apple.quicklook.preview",
            familyOutput: "+    com.91wan.MarkLook.Preview(0.1.0) /Applications/MarkLook.app",
            familyTerminationStatus: 0,
            exactOutput: "com.91wan.MarkLook.Preview registered enabled",
            exactTerminationStatus: 0
        )

        XCTAssertEqual(status.familyQueryState, .present)
        XCTAssertEqual(status.exactQueryState, .present)
        XCTAssertEqual(status.effectiveStatus, .registered)
    }

    func testExactBundlePresentWithMissingFamilyListingIsIncompleteListing() {
        let status = ExtensionRegistrationStatus.parse(
            displayName: "Thumbnail",
            bundleIdentifier: "com.91wan.MarkLook.Thumbnail",
            familyIdentifier: "com.apple.quicklook.thumbnail",
            familyOutput: "",
            familyTerminationStatus: 0,
            exactOutput: "com.91wan.MarkLook.Thumbnail registered enabled",
            exactTerminationStatus: 0
        )

        XCTAssertEqual(status.familyQueryState, .missing)
        XCTAssertEqual(status.exactQueryState, .present)
        XCTAssertEqual(status.effectiveStatus, .incompleteListing)
    }

    func testBundleOutputPresentWinsOverNonzeroExitStatus() {
        let status = ExtensionRegistrationStatus.parse(
            displayName: "Preview",
            bundleIdentifier: "com.91wan.MarkLook.Preview",
            familyIdentifier: "com.apple.quicklook.preview",
            familyOutput: "com.91wan.MarkLook.Preview",
            familyTerminationStatus: 1,
            exactOutput: "com.91wan.MarkLook.Preview",
            exactTerminationStatus: 1
        )

        XCTAssertEqual(status.familyQueryState, .present)
        XCTAssertEqual(status.exactQueryState, .present)
        XCTAssertEqual(status.effectiveStatus, .registered)
    }

    func testBothFamilyAndExactMissingIsMissing() {
        let status = ExtensionRegistrationStatus.parse(
            displayName: "Thumbnail",
            bundleIdentifier: "com.91wan.MarkLook.Thumbnail",
            familyIdentifier: "com.apple.quicklook.thumbnail",
            familyOutput: "",
            familyTerminationStatus: 0,
            exactOutput: "",
            exactTerminationStatus: 0
        )

        XCTAssertEqual(status.familyQueryState, .missing)
        XCTAssertEqual(status.exactQueryState, .missing)
        XCTAssertEqual(status.effectiveStatus, .missing)
    }
}
