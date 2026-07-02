# Changelog

## 0.1.1 - 2026-07-02

### Fixed

- Made Markdown thumbnail rendering deterministic and non-overlapping for Finder icon view.
- Preserved the fixed light thumbnail appearance policy for v0.1.x so Finder cache and appearance contexts produce the same thumbnail output.

### Security / Privacy

- Removed public runtime evidence images from the current repository tree.
- Added a permanent public-repository privacy gate for current and archived repository scans.

### Documentation

- Documented the v0.1.x fixed light thumbnail appearance policy.
- Added `README_ZH.md` and linked it from the English README.
- Added v0.1.1 source/local-validation gate documentation.

### Validation

- v0.1.1 is prepared as a source/local-validation patch only.
- App and Quick Look extension bundle metadata use `CFBundleShortVersionString=0.1.1` and `CFBundleVersion=2`.
- CI-compatible and local Apple Development validation must pass on the final merged commit before any tag is created.
- Public notarized binary distribution still requires Developer ID Application signing, hardened runtime, notarization, and stapling.

## 0.1.0 - 2026-06-30

### Added

- Modern macOS host app with Quick Look Preview and Thumbnail app extensions.
- Data-based Quick Look Markdown preview using `QLPreviewReply(dataOfContentType: .html)`.
- Local MarkdownCore safe HTML renderer for the v0.1 Markdown subset.
- Bounded Markdown thumbnail renderer.
- Diagnostics dashboard for extension registration, supported Markdown types, selected-file diagnosis, Quick Look cache reset, and report copying.
- Signed local Apple Development validation scripts.
- Debug packaging scripts, package artifact validation, release prep docs, and AppIcon packaging.

### Security / Privacy

- Local rendering only.
- No telemetry.
- No network entitlement.
- No remote resource loading during preview rendering.
- No `.qlgenerator`.
- No Finder Sync extension.
- No Electron.

### Known Limitations

- Public distribution still requires Developer ID Application signing, hardened runtime, notarization, and stapling.
- Apple Development packages are local validation artifacts only.
- Unsigned CI packages are not installable trust artifacts.
- Finder/Quick Look provider selection can vary by host registration state; use the diagnostics dashboard and scripts.

### Validation

- CI build/test: passed in the v0.1.0 release candidate gate.
- Signed local validation: passed with a redacted Apple Development Team ID on the maintainer Mac.
- Finder Space preview: pending owner/manual acceptance.
- Thumbnail validation: passed with `/Applications/MarkLook.app` as the only active MarkLook PlugInKit registration.
- Diagnostics dashboard: covered by the release candidate gate and local signed validation.
- Packaging validation: passed for unsigned CI and Apple Development local artifacts.
