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
            fileURL: URL(fileURLWithPath: "/tmp/marklook-private/Documents/basic.md"),
            mdlsSucceeded: true
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
        XCTAssertTrue(diagnostic.hasKnownFileExtension)
        XCTAssertEqual(diagnostic.quickLookUTIMatch, .matched)
    }

    func testUnknownSubtypeDoesNotCreateExactQuickLookMatchFromTypeTree() {
        let output = """
        kMDItemContentType = "com.example.markdown-subtype"
        kMDItemContentTypeTree = (
            "com.example.markdown-subtype",
            "net.daringfireball.markdown",
            "public.text"
        )
        """

        let diagnostic = FileDiagnostic.parse(
            mdlsOutput: output,
            fileURL: URL(fileURLWithPath: "/tmp/marklook-private/Documents/notes.md"),
            mdlsSucceeded: true
        )

        XCTAssertEqual(diagnostic.contentType, "com.example.markdown-subtype")
        XCTAssertTrue(diagnostic.hasKnownFileExtension)
        XCTAssertEqual(diagnostic.quickLookUTIMatch, .notMatched)
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
            fileURL: URL(fileURLWithPath: "/tmp/marklook-private/Documents/blob.bin"),
            mdlsSucceeded: true
        )

        XCTAssertFalse(diagnostic.hasKnownFileExtension)
        XCTAssertEqual(diagnostic.quickLookUTIMatch, .notMatched)
    }

    func testKnownExtensionDoesNotCreateQuickLookUTIMatch() {
        let output = """
        kMDItemContentType = "dyn.ah62d4rv4ge8043d2"
        kMDItemContentTypeTree = (
            "dyn.ah62d4rv4ge8043d2",
            "public.text",
            "public.data"
        )
        """

        let diagnostic = FileDiagnostic.parse(
            mdlsOutput: output,
            fileURL: URL(fileURLWithPath: "/tmp/marklook-private/Documents/component.mdx"),
            mdlsSucceeded: true
        )

        XCTAssertTrue(diagnostic.hasKnownFileExtension)
        XCTAssertEqual(diagnostic.quickLookUTIMatch, .notMatched)
    }

    func testDeclaredMDXTypeMatchesQuickLook() {
        let output = """
        kMDItemContentType = "com.91wan.marklook.mdx"
        kMDItemContentTypeTree = (
            "com.91wan.marklook.mdx",
            "public.text",
            "public.data"
        )
        """

        let diagnostic = FileDiagnostic.parse(
            mdlsOutput: output,
            fileURL: URL(fileURLWithPath: "/tmp/marklook-private/Documents/component.mdx"),
            mdlsSucceeded: true
        )

        XCTAssertTrue(diagnostic.hasKnownFileExtension)
        XCTAssertEqual(diagnostic.quickLookUTIMatch, .matched)
    }

    func testMissingMDLSOutputMakesQuickLookMatchUnavailable() {
        let diagnostic = FileDiagnostic.parse(
            mdlsOutput: "",
            fileURL: URL(fileURLWithPath: "/tmp/marklook-private/Documents/notes.md"),
            mdlsSucceeded: true
        )

        XCTAssertEqual(diagnostic.contentType, "unavailable")
        XCTAssertTrue(diagnostic.hasKnownFileExtension)
        XCTAssertEqual(diagnostic.quickLookUTIMatch, .unavailable)
    }

    func testFailedMDLSCommandMakesQuickLookMatchUnavailable() {
        let output = """
        kMDItemContentType = "net.daringfireball.markdown"
        """

        let diagnostic = FileDiagnostic.parse(
            mdlsOutput: output,
            fileURL: URL(fileURLWithPath: "/tmp/marklook-private/Documents/notes.md"),
            mdlsSucceeded: false
        )

        XCTAssertEqual(diagnostic.contentType, "net.daringfireball.markdown")
        XCTAssertEqual(diagnostic.quickLookUTIMatch, .unavailable)
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
