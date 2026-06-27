# ADR-0002: Markdown Engine

## Status

Accepted for Issue #3 v0.1

## Context

MarkLook needs local Markdown rendering with GFM basics: tables, task lists, fenced code blocks, blockquotes, lists, and links. Raw HTML and remote resources must not execute or load during Quick Look preview rendering.

## Decision

Issue #3 will ship an internal MarkdownCore v0.1 renderer rather than adopting an external Markdown dependency.

Reasons:

- The current CI runner builds with Xcode 16.4. `swiftlang/swift-markdown` main currently requires a newer Swift tools version than this project can assume, so pinning main is not acceptable.
- cmark-gfm wrappers add C dependency and app-extension compatibility questions that should not block a safe renderer baseline.
- MarkLook needs a deterministic, testable security policy before Finder/WebKit integration.
- The v0.1 renderer can cover the required product subset while keeping the dependency surface at Foundation only.

License: project-owned source under the repository license.

SwiftPM compatibility: `swift-tools-version: 6.0`, macOS 14 minimum.

Xcode version tested: local Xcode 17.x and GitHub Actions Xcode 16.4 through SwiftPM and app-extension build gates.

App extension compatibility: MarkdownCore must import Foundation only and must not import WebKit or AppKit.

GFM support level for v0.1:

- headings `#` / `##` / `###`
- paragraphs
- unordered and ordered lists
- blockquotes
- fenced code blocks
- inline code
- GFM-style tables
- GFM task lists
- horizontal rules
- links
- images with resource-policy handling
- YAML front matter extraction
- basic table of contents extraction

Deferred:

- Mermaid
- KaTeX / MathJax
- syntax highlighting
- local image loading
- source/render toggle
- copy code button
- TOC sidebar UI

Fallback plan: if the internal subset becomes too costly or fails compatibility requirements, update this ADR before replacing it with a pinned app-extension-compatible dependency. The update must document dependency name, license, SwiftPM compatibility, CI result, raw HTML behavior, remote resource handling, and fallback behavior.

## Security policy

- Raw HTML must be disabled or sanitized.
- Script tags must not enter an executable context.
- Remote images must be blocked or replaced with safe placeholders.
- Links may be displayed, but Quick Look navigation must be cancelled.
- Output HTML must be self-contained with inline CSS and a restrictive CSP.
- Runtime network access is not allowed in MarkdownCore.
- MarkdownCore must not read or write files.

## Fallback rule

If the preferred dependency fails in the app extension or CI environment, replace it only after updating this ADR with:

- original failure reason
- replacement dependency
- license
- app extension compatibility
- CI result
- raw HTML safety strategy
