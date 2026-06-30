# v0.1.0 Performance Notes

## Environment

- Source commit: PR worktree validation reported `3a77330b28b70f04bca42116287b71769a1f6205`; rerun on final PR head and latest `main` before tagging.
- macOS: 26.5.1 (25F80)
- Xcode: 26.6 (17F113)
- Hardware: Mac16,12

## Preview Architecture

MarkLook Preview is data-based HTML returned through `QLPreviewReply(dataOfContentType: .html)`. It does not embed `WKWebView`, and the Preview extension does not import WebKit.

MarkdownCore builds a self-contained HTML document with a restrictive resource policy. Raw HTML is escaped or sanitized, remote resources are blocked, and links are inert.

## Thumbnail Architecture

The Thumbnail extension does not use MarkdownCore full render. It extracts bounded Markdown metadata and draws a Markdown identity thumbnail directly. The metadata loader reads a bounded prefix; the default prefix limit is 64 KiB.

## Large-File Behavior

Preview loading has bounded large-file behavior. Large input can enter fast mode and show a warning instead of attempting a full expensive render. Thumbnail metadata stays prefix-based and records approximate line counts.

## Diagnostics Command Bounds

Diagnostics commands use explicit command execution paths with timeout and output truncation. The dashboard is a local diagnostics/install-assistance surface, not an editor or networked service.

## Manual Measurements

Captured on the maintainer Mac after installing `/Applications/MarkLook.app` with Apple Development signing. These are smoke timings, not benchmark claims.

```text
Scripts/validate-signed-quicklook.sh --development --noninteractive /Applications/MarkLook.app
real 3.50s
max RSS 72,695,808 bytes

qlmanage -t -x -s 512 -o /tmp Samples/basic.md
real 0.02s
max RSS 22,036,480 bytes

qlmanage -t -x -s 512 -o /tmp Samples/large-fast-mode.md
real 0.02s
max RSS 22,134,784 bytes
```

Suggested commands for final latest-main validation:

```bash
/usr/bin/time -lp Scripts/validate-signed-quicklook.sh --development --noninteractive /Applications/MarkLook.app
/usr/bin/time -lp qlmanage -t -x -s 512 -o /tmp Samples/basic.md
/usr/bin/time -lp qlmanage -t -x -s 512 -o /tmp Samples/large-fast-mode.md
```

If timing cannot be captured reliably, the release gate records functional validation instead of invented benchmark numbers.

## Non-Goals

- No Markdown editing.
- No telemetry.
- No remote rendering.
- No network fetches for preview resources.
- No provider-priority hacks outside normal macOS Quick Look registration.

## Known Performance Risks

- Finder/Quick Look provider selection can vary by host registration state and cache state.
- Very large documents may use fast mode and show a warning.
- Thumbnail line counts are approximate because they are prefix-based.
- Public distribution signing/notarization can change launch and first-registration timing and must be validated separately.
