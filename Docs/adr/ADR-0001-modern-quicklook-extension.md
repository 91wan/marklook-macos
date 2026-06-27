# ADR-0001: Use Modern Quick Look App Extensions

## Status

Accepted draft

## Context

MarkLook needs to render Markdown in Finder Quick Look on modern macOS. Apple supports Quick Look preview and thumbnail app extensions for this use case. Deprecated `.qlgenerator` plugins are outside the product boundary.

## Decision

MarkLook will ship as a macOS app containing:

- a Quick Look Preview Extension
- a Quick Look Thumbnail Extension
- a host app for diagnostics and setup guidance
- a local MarkdownCore Swift package

MarkLook will not implement a deprecated `.qlgenerator`, Finder Sync extension, Electron app, or Markdown editor.

## Consequences

- The app follows the modern extension distribution path.
- Users may need to enable the Quick Look extension in System Settings.
- Build and packaging must handle app extension targets.
- Runtime validation should use `qlmanage`, `pluginkit`, and Finder.
