# Review checklist

Use this checklist for every pull request.

## Scope

- The change stays inside the current issue.
- Behavior changes are explicitly listed, or the PR says `behavior changes: none`.
- Architecture changes have an ADR before implementation.

## Validation

- Commands are listed exactly.
- Results are summarized clearly.
- Failures, skipped checks, and local-only limitations are disclosed.
- Diagnostics UI changes include MarkLookAppTests and `Scripts/validate-diagnostics-boundaries.sh`.

## Security and privacy

- No network access is added without explicit review.
- No telemetry is added.
- Raw HTML and scripts remain disabled or sanitized.
- Remote resources are not loaded during preview rendering.
- Sandbox and Hardened Runtime settings are preserved or explained.
- MarkdownCore remains free of WebKit and AppKit imports.
- PreviewExtension remains free of WebKit imports and `WKWebView`.
- Renderer HTML remains self-contained with a restrictive CSP.

## Quick Look

- Preview extension changes include rendered preview validation when relevant.
- Thumbnail extension changes include thumbnail validation when relevant.
- Thumbnail extension changes prove bounded metadata extraction and must not use WebKit, MarkdownCore full rendering, or unbounded full-file reads.
- Signed Quick Look validation states whether `--noninteractive` or `--interactive-preview` was run.
- Preview extension stays data-based for v0.1: `QLIsDataBasedPreview=true`, and `PreviewViewController` implements `providePreview`.
- Do not mix the data-based plist flag with `preparePreviewOfFile` or any `WKWebView` path.
- `QLSupportedContentTypes` changes avoid `public.plain-text`.
- Cache reset commands are documented when behavior changes.
- Host app remains diagnostics/install assistance only: no editor UI, telemetry, network access, remote resources, or clickable web navigation.

## Release

- Public docs remain accurate.
- Known limitations are recorded when applicable.
- Packaging changes include `Scripts/package-debug.sh`, `Scripts/validate-package-artifact.sh`, script tests, and release docs.
- Debug packages record whether they are unsigned CI or Apple Development local-only artifacts.
- AppIcon packaging status is explicit; do not silently ship a generic icon for a polished v0.1 candidate.
- Developer ID signing, notarization, and stapling are documented as public-release requirements when they are not performed.
- Do not create the `v0.1.0` tag, publish a GitHub Release, or submit a Homebrew cask before the release issue explicitly authorizes it.
- v0.1.0 hardening changes include `CHANGELOG.md`, performance notes, manual validation log, known limitations, release gate docs, and `Scripts/validate-v0.1.0-release-candidate.sh`.
- The release candidate package path and checksum come from latest `main` or the current PR head under review, not stale PR artifacts.
- The `v0.1.0` tag is pushed only after merge, final latest-main validation, and explicit owner approval.
