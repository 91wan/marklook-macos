# Changelog

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
- Signed local validation: passed with Apple Development Team ID `W2SP34K4MR` on the maintainer Mac.
- Finder Space preview: pending owner/manual acceptance.
- Thumbnail validation: passed with `/Applications/MarkLook.app` as the only active MarkLook PlugInKit registration.
- Diagnostics dashboard: covered by the release candidate gate and local signed validation.
- Packaging validation: passed for unsigned CI and Apple Development local artifacts.
