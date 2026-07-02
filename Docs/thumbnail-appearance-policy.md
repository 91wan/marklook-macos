# Thumbnail appearance policy

## Decision

For v0.1.x, MarkLook thumbnails use one fixed light document-card palette.

## Rationale

- Finder thumbnails must be deterministic.
- Quick Look thumbnail workers can run under different or cached appearance contexts.
- `NSAppearance.current` and dynamic AppKit system colors are not allowed in ThumbnailExtension.
- A light document card remains legible in both light and dark Finder appearances.
- A stable thumbnail is more important than adaptive styling for v0.1.x.

## Current implementation

- `MarkdownThumbnailPalette.v0Light`
- `MarkdownThumbnailLayout`
- fixed sRGB colors
- non-overlapping badge / title / footer regions
- long title/filename clamping

## Deferred option

A dark/gray palette may be considered after v0.1.x only if:

- the palette is explicit and deterministic
- it does not depend on ambient `NSAppearance.current`
- it does not use dynamic system colors
- it has renderer/layout/determinism tests
- Finder cache behavior is validated with text-only or sanitized evidence

## Non-goals

- no ambient dark-mode adaptation
- no dynamic system colors
- no WebKit
- no MarkdownCore full render in thumbnails
- no release publication
