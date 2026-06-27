# ADR-0002: Markdown Engine

## Status

Proposed draft

## Context

MarkLook needs local Markdown rendering with GFM basics: tables, task lists, fenced code blocks, blockquotes, lists, and links. Raw HTML and remote resources must not execute or load during Quick Look preview rendering.

## Decision

The preferred initial direction is a cmark-gfm compatible Swift package such as Down-gfm or another app-extension-compatible cmark-gfm wrapper. The engine must compile on a clean macOS runner through Swift Package Manager and XcodeGen-generated app extension targets.

## Security policy

- Raw HTML must be disabled or sanitized.
- Script tags must not enter an executable context.
- Remote images must be blocked or replaced with safe placeholders.
- Links may be displayed, but Quick Look navigation must be cancelled.

## Fallback rule

If the preferred dependency fails in the app extension or CI environment, replace it only after updating this ADR with:

- original failure reason
- replacement dependency
- license
- app extension compatibility
- CI result
- raw HTML safety strategy
