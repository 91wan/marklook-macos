# MarkLook v0.1.0 release draft

Do not publish this draft until Issue #8 completes.

## Release title

MarkLook v0.1.0

## Summary

MarkLook is a fast, local macOS Quick Look reader for Markdown files, focused on AI and developer long-form documents.

## What's included

- macOS host app with Quick Look diagnostics dashboard
- Quick Look Preview extension for safe, self-contained Markdown HTML preview
- Quick Look Thumbnail extension with bounded Markdown identity thumbnails
- MarkdownCore renderer for the v0.1 Markdown subset
- Supported Markdown content types and extensions for common AI/developer docs
- Local diagnostics for PlugInKit registration, selected-file `mdls` content type, Quick Look cache reset, and report copying
- Debug package scripts and package artifact validation

## Known limitations

- Public release packaging is not complete until Developer ID signing, notarization, and stapling are performed.
- Apple Development packages are local validation artifacts only.
- Unsigned CI packages are not installable trust artifacts.
- Finder provider selection can vary by host registration state; use the diagnostics dashboard and validation scripts when debugging.
- Homebrew cask content is draft-only until a real release artifact URL and SHA-256 exist.

## Install notes

1. Download the final release artifact after Issue #8 completes.
2. Install `MarkLook.app` into `/Applications`.
3. Open MarkLook once.
4. Enable MarkLook Quick Look extensions if macOS shows them under System Settings -> General -> Login Items & Extensions -> Quick Look.
5. Reset Quick Look if needed:

```bash
qlmanage -r
qlmanage -r cache
killall Finder || true
```

## Local validation summary

- CI build and tests: passed in the v0.1.0 release candidate gate on the PR worktree; rerun on latest `main` before tagging.
- Apple Development local validation: passed with Team ID `W2SP34K4MR` on the maintainer Mac; rerun on latest `main` before tagging.
- Finder Space preview validation: owner/manual acceptance still required or explicitly deferred before tagging.
- Thumbnail validation: passed with `/Applications/MarkLook.app` as the only active MarkLook PlugInKit registration.
- Diagnostics dashboard acceptance: covered by local signed validation; final owner acceptance still required for release closure.
- Package validation: unsigned CI and Apple Development local artifacts passed validation; public release artifact still pending Developer ID/notarization.

## Checksums

```text
MarkLook-0.1.0.zip SHA-256: pending final release artifact
```

## Release artifact

```text
https://github.com/91wan/marklook-macos/releases/download/v0.1.0/MarkLook-0.1.0.zip
```

## Developer ID / notarization status

```text
Developer ID Application signing: pending until Issue #8
Notarization: pending until Issue #8
Stapling: pending until Issue #8
spctl assessment: pending until Issue #8
```
